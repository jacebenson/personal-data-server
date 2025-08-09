class ContactMergeService
  attr_reader :user, :merge_results

  def initialize(user)
    @user = user
    @merge_results = {
      total_contacts: 0,
      duplicate_groups: 0,
      contacts_merged: 0,
      contacts_removed: 0,
      errors: []
    }
  end

  # Find all potential duplicate groups
  def find_duplicates
    @merge_results[:total_contacts] = @user.contacts.count
    duplicate_groups = []

    # Group 1: Exact email matches
    email_groups = find_email_duplicates
    duplicate_groups.concat(email_groups)

    # Group 2: Exact phone matches (excluding those already in email groups)
    already_grouped_ids = duplicate_groups.flatten.map(&:id)
    phone_groups = find_phone_duplicates.reject do |group|
      group.any? { |contact| already_grouped_ids.include?(contact.id) }
    end
    duplicate_groups.concat(phone_groups)

    # Group 3: Name-based matches (excluding those already grouped)
    already_grouped_ids = duplicate_groups.flatten.map(&:id)
    name_groups = find_name_duplicates.reject do |group|
      group.any? { |contact| already_grouped_ids.include?(contact.id) }
    end
    duplicate_groups.concat(name_groups)

    # Filter out any groups with less than 2 contacts (safety check)
    duplicate_groups = duplicate_groups.select { |group| group.length >= 2 }

    @merge_results[:duplicate_groups] = duplicate_groups.length
    duplicate_groups
  end

  # Automatically merge all found duplicates
  def auto_merge_all!
    duplicate_groups = find_duplicates

    duplicate_groups.each do |group|
      begin
        merge_contact_group!(group)
      rescue => e
        @merge_results[:errors] << "Error merging group: #{e.message}"
      end
    end

    @merge_results
  end

  # Merge a specific group of contacts
  def merge_contact_group!(contacts)
    return if contacts.length < 2

    # Sort by most complete contact (has most data) and most recent
    primary_contact = select_primary_contact(contacts)
    secondary_contacts = contacts - [ primary_contact ]

    # Merge data from secondary contacts into primary
    merge_contact_data!(primary_contact, secondary_contacts)

    # Delete secondary contacts
    secondary_contacts.each do |contact|
      contact.destroy!
      @merge_results[:contacts_removed] += 1
    end

    @merge_results[:contacts_merged] += 1
    primary_contact
  end

  private

  def find_email_duplicates
    # Find contacts that share at least one email address
    contacts_with_emails = @user.contacts.where.not(emails: [ nil, "" ])

    email_to_contacts = {}
    contacts_with_emails.each do |contact|
      contact.email_list.each do |email|
        normalized_email = email.downcase.strip
        next if normalized_email.blank?

        email_to_contacts[normalized_email] ||= []
        email_to_contacts[normalized_email] << contact
      end
    end

    # Return groups with more than one contact, remove duplicates
    groups = email_to_contacts.values.select { |contacts| contacts.length > 1 }.map(&:uniq)
    groups.select { |group| group.length > 1 }
  end

  def find_phone_duplicates
    # Find contacts that share at least one phone number
    contacts_with_phones = @user.contacts.where.not(phones: [ nil, "" ])

    phone_to_contacts = {}
    contacts_with_phones.each do |contact|
      contact.phone_list.each do |phone|
        normalized_phone = normalize_phone(phone)
        next if normalized_phone.blank?

        phone_to_contacts[normalized_phone] ||= []
        phone_to_contacts[normalized_phone] << contact
      end
    end

    # Return groups with more than one contact, remove duplicates
    groups = phone_to_contacts.values.select { |contacts| contacts.length > 1 }.map(&:uniq)
    groups.select { |group| group.length > 1 }
  end

  def find_name_duplicates
    # Find contacts with same first+last name combination
    contacts_with_names = @user.contacts.where.not(given_name: [ nil, "" ], family_name: [ nil, "" ])

    name_to_contacts = {}
    contacts_with_names.each do |contact|
      name_key = "#{contact.given_name&.downcase&.strip}|#{contact.family_name&.downcase&.strip}"
      next if name_key == "|" # Skip if both names are blank

      name_to_contacts[name_key] ||= []
      name_to_contacts[name_key] << contact
    end

    # Also check display_name matches
    contacts_with_display = @user.contacts.where.not(display_name: [ nil, "" ])
    contacts_with_display.each do |contact|
      display_name = contact.display_name&.downcase&.strip
      next if display_name.blank?

      display_key = "display|#{display_name}"
      name_to_contacts[display_key] ||= []
      name_to_contacts[display_key] << contact
    end

    # Return groups with more than one contact, remove duplicates
    groups = name_to_contacts.values.select { |contacts| contacts.length > 1 }.map(&:uniq)
    groups.select { |group| group.length > 1 }
  end

  def normalize_phone(phone)
    # Remove all non-digit characters and common prefixes
    normalized = phone.gsub(/\D/, "")

    # Remove country code if present
    if normalized.length == 11 && normalized.start_with?("1")
      normalized = normalized[1..-1]
    elsif normalized.length > 10
      # For other country codes, keep as is for now
    end

    normalized.length >= 10 ? normalized : nil
  end

  def select_primary_contact(contacts)
    # Score contacts based on completeness and recency
    scored_contacts = contacts.map do |contact|
      score = calculate_contact_completeness_score(contact)
      { contact: contact, score: score }
    end

    # Sort by score (descending) then by created_at (most recent first)
    scored_contacts.sort_by { |item| [ -item[:score], -item[:contact].created_at.to_i ] }.first[:contact]
  end

  def calculate_contact_completeness_score(contact)
    score = 0

    # Basic info
    score += 10 if contact.given_name.present?
    score += 10 if contact.family_name.present?
    score += 15 if contact.display_name.present?
    score += 5 if contact.nickname.present?

    # Contact methods
    score += contact.email_list.length * 8
    score += contact.phone_list.length * 8
    score += 5 if contact.address.present?

    # Organization
    score += 10 if contact.organization.present?
    score += 5 if contact.job_title.present?
    score += 3 if contact.department.present?

    # Additional data
    score += 5 if contact.birthday.present?
    score += 3 if contact.notes.present?
    score += 2 if contact.categories.present?
    score += 2 if contact.social_profiles.present?

    # Prefer contacts with more recent data
    score += 5 if contact.last_modified.present?

    score
  end

  def merge_contact_data!(primary, secondary_contacts)
    # Collect all data from secondary contacts
    all_emails = Set.new(primary.email_list)
    all_phones = Set.new(primary.phone_list)
    all_urls = primary.urls ? primary.urls.split(",").map(&:strip) : []

    notes_parts = []
    notes_parts << primary.notes if primary.notes.present?

    categories_set = Set.new
    if primary.categories.present?
      categories_set.merge(primary.categories.split(",").map(&:strip))
    end

    # Merge data from secondary contacts
    secondary_contacts.each do |secondary|
      # Merge contact methods
      all_emails.merge(secondary.email_list)
      all_phones.merge(secondary.phone_list)

      if secondary.urls.present?
        all_urls.concat(secondary.urls.split(",").map(&:strip))
      end

      # Fill in missing basic info (prefer primary, but fill gaps)
      primary.given_name = secondary.given_name if primary.given_name.blank? && secondary.given_name.present?
      primary.family_name = secondary.family_name if primary.family_name.blank? && secondary.family_name.present?
      primary.middle_name = secondary.middle_name if primary.middle_name.blank? && secondary.middle_name.present?
      primary.display_name = secondary.display_name if primary.display_name.blank? && secondary.display_name.present?
      primary.nickname = secondary.nickname if primary.nickname.blank? && secondary.nickname.present?
      primary.name_prefix = secondary.name_prefix if primary.name_prefix.blank? && secondary.name_prefix.present?
      primary.name_suffix = secondary.name_suffix if primary.name_suffix.blank? && secondary.name_suffix.present?

      # Organization info
      primary.organization = secondary.organization if primary.organization.blank? && secondary.organization.present?
      primary.job_title = secondary.job_title if primary.job_title.blank? && secondary.job_title.present?
      primary.department = secondary.department if primary.department.blank? && secondary.department.present?

      # Personal info
      primary.birthday = secondary.birthday if primary.birthday.blank? && secondary.birthday.present?
      primary.address = secondary.address if primary.address.blank? && secondary.address.present?

      # Photo
      if primary.photo_url.blank? && secondary.photo_url.present?
        primary.photo_url = secondary.photo_url
      end
      if primary.photo_data.blank? && secondary.photo_data.present?
        primary.photo_data = secondary.photo_data
      end

      # Social profiles
      if primary.social_profiles.blank? && secondary.social_profiles.present?
        primary.social_profiles = secondary.social_profiles
      elsif primary.social_profiles.present? && secondary.social_profiles.present?
        begin
          primary_profiles = JSON.parse(primary.social_profiles)
          secondary_profiles = JSON.parse(secondary.social_profiles)
          merged_profiles = primary_profiles.merge(secondary_profiles)
          primary.social_profiles = merged_profiles.to_json
        rescue JSON::ParserError
          # Keep primary if there's a parsing error
        end
      end

      # Merge notes
      if secondary.notes.present?
        notes_parts << "#{secondary.full_name}: #{secondary.notes}"
      end

      # Merge categories
      if secondary.categories.present?
        categories_set.merge(secondary.categories.split(",").map(&:strip))
      end

      # Keep the most recent last_modified date
      if secondary.last_modified.present? &&
         (primary.last_modified.blank? || secondary.last_modified > primary.last_modified)
        primary.last_modified = secondary.last_modified
      end
    end

    # Update primary contact with merged data
    primary.emails = all_emails.to_a.join(",") if all_emails.any?
    primary.phones = all_phones.to_a.join(",") if all_phones.any?
    primary.urls = all_urls.uniq.join(",") if all_urls.any?
    primary.notes = notes_parts.join("\n\n") if notes_parts.length > 1
    primary.categories = categories_set.to_a.join(",") if categories_set.any?

    primary.save!
  end
end
