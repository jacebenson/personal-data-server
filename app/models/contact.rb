class Contact < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true
  validates :uid, presence: true, uniqueness: { scope: :user_id }

  scope :by_source, ->(source) { where(source: source) }
  scope :recent, -> { order(created_at: :desc) }
  scope :alphabetical, -> { order(:display_name, :given_name, :family_name) }
  scope :search, ->(term) do
    return all if term.blank?

    search_term = "%#{term}%"
    where(
      "display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE OR emails LIKE ? COLLATE NOCASE",
      search_term, search_term, search_term, search_term, search_term
    )
  end

  def full_name
    if display_name.present?
      display_name
    elsif given_name.present? || family_name.present?
      [ given_name, family_name ].compact.join(" ")
    elsif organization.present?
      organization
    else
      "Unknown Contact"
    end
  end

  def primary_email
    emails.present? ? emails.split(",").first.strip : nil
  end

  def primary_phone
    phones.present? ? phones.split(",").first.strip : nil
  end

  def email_list
    emails.present? ? emails.split(",").map(&:strip) : []
  end

  def phone_list
    phones.present? ? phones.split(",").map(&:strip) : []
  end

  def formatted_address
    return nil unless address.present?

    # Parse address components if stored as JSON
    if address.start_with?("{")
      begin
        addr = JSON.parse(address)
        [
          addr["street"],
          addr["city"],
          addr["state"],
          addr["postal_code"],
          addr["country"]
        ].compact.join(", ")
      rescue JSON::ParserError
        address
      end
    else
      address
    end
  end

  def initials
    if given_name.present? && family_name.present?
      "#{given_name.first}#{family_name.first}".upcase
    elsif display_name.present?
      words = display_name.split(" ")
      if words.length >= 2
        "#{words.first.first}#{words.last.first}".upcase
      else
        display_name.first.upcase
      end
    elsif organization.present?
      organization.first.upcase
    else
      "?"
    end
  end

  def has_contact_info?
    emails.present? || phones.present? || address.present?
  end

  def contact_methods_count
    count = 0
    count += email_list.length if emails.present?
    count += phone_list.length if phones.present?
    count += 1 if address.present?
    count
  end

  def linkedin_url
    return nil unless social_profiles.present?

    # Look for LinkedIn URL in social profiles
    social_profiles.lines.each do |line|
      if line.include?("linkedin.com") || line.downcase.include?("linkedin:")
        # Extract URL from the line
        url_match = line.match(/(https?:\/\/[^\s]+)/)
        return url_match[1] if url_match

        # Handle "LinkedIn: URL" format
        if line.include?(":")
          url = line.split(":", 2).last.strip
          return url if url.start_with?("http")
        end
      end
    end

    nil
  end

  def social_profile_links
    return [] unless social_profiles.present?

    links = []
    social_profiles.lines.each do |line|
      line = line.strip
      next if line.blank?

      if line.include?(":")
        platform, url = line.split(":", 2)
        platform = platform.strip
        url = url.strip

        if url.start_with?("http")
          links << { platform: platform, url: url }
        end
      elsif line.start_with?("http")
        # Direct URL without platform label
        if line.include?("linkedin.com")
          links << { platform: "LinkedIn", url: line }
        elsif line.include?("twitter.com") || line.include?("x.com")
          links << { platform: "Twitter/X", url: line }
        else
          links << { platform: "Website", url: line }
        end
      end
    end

    links
  end

  # Check if this contact might be a duplicate of another
  def potential_duplicates
    return Contact.none unless user_id.present?

    candidates = user.contacts.where.not(id: id)

    # Check for email matches
    if emails.present?
      email_matches = candidates.where(
        email_list.map { |email| "emails LIKE ?" }.join(" OR "),
        *email_list.map { |email| "%#{email}%" }
      )
      return email_matches if email_matches.any?
    end

    # Check for phone matches
    if phones.present?
      phone_matches = candidates.where(
        phone_list.map { |phone| "phones LIKE ?" }.join(" OR "),
        *phone_list.map { |phone| "%#{phone.gsub(/\D/, '')}%" }
      )
      return phone_matches if phone_matches.any?
    end

    # Check for name matches
    if given_name.present? && family_name.present?
      name_matches = candidates.where(
        given_name: given_name,
        family_name: family_name
      )
      return name_matches if name_matches.any?
    end

    Contact.none
  end

  # Calculate completeness score for merge decisions
  def completeness_score
    score = 0

    # Basic info
    score += 10 if given_name.present?
    score += 10 if family_name.present?
    score += 15 if display_name.present?
    score += 5 if nickname.present?

    # Contact methods
    score += email_list.length * 8
    score += phone_list.length * 8
    score += 5 if address.present?

    # Organization
    score += 10 if organization.present?
    score += 5 if job_title.present?
    score += 3 if department.present?

    # Additional data
    score += 5 if birthday.present?
    score += 3 if notes.present?
    score += 2 if categories.present?
    score += 2 if social_profiles.present?

    # Prefer contacts with more recent data
    score += 5 if last_modified.present?

    score
  end
end
