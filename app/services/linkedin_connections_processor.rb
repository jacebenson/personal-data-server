require "csv"

class LinkedinConnectionsProcessor
  attr_reader :results

  def initialize(user, custom_source = nil)
    @user = user
    @custom_source = custom_source
    @results = {
      processed: 0,
      created: 0,
      updated: 0,
      errors: []
    }
  end

  def process_csv_file(file_path)
    begin
      # Read the CSV file, skipping the first 3 comment lines
      csv_content = File.read(file_path)
      lines = csv_content.lines

      # Skip first 3 lines (comments) and use line 4 as headers
      if lines.length < 4
        @results[:errors] << "File must have at least 4 lines (3 comment lines + header)"
        return @results
      end

      # Extract data starting from line 5 (index 4)
      data_lines = lines[3..-1] # Skip first 3 comment lines, include header and data
      csv_data = data_lines.join

      CSV.parse(csv_data, headers: true, header_converters: :symbol) do |row|
        process_connection_row(row)
      end

    rescue => e
      @results[:errors] << "Error processing CSV: #{e.message}"
    end

    @results
  end

  private

  def process_connection_row(row)
    @results[:processed] += 1

    begin
      # Extract connection data from CSV row
      # Common LinkedIn export columns: First Name, Last Name, Email Address, Company, Position
      contact_data = extract_contact_data(row)

      return if contact_data[:skip]

      # Create or update contact
      contact = find_or_create_contact(contact_data)

      if contact.persisted?
        if contact.previously_new_record?
          @results[:created] += 1
        else
          @results[:updated] += 1
        end
      else
        @results[:errors] << "Failed to save contact: #{contact.errors.full_messages.join(', ')}"
      end

    rescue => e
      @results[:errors] << "Error processing row #{@results[:processed]}: #{e.message}"
    end
  end

  def extract_contact_data(row)
    # Handle various possible column names from LinkedIn exports
    first_name = find_column_value(row, [ :first_name, :"first name", :firstname, :given_name ])
    last_name = find_column_value(row, [ :last_name, :"last name", :lastname, :family_name, :surname ])
    email = find_column_value(row, [ :email_address, :"email address", :email ])
    company = find_column_value(row, [ :company, :organization, :employer ])
    position = find_column_value(row, [ :position, :title, :job_title, :"job title" ])
    linkedin_url = find_column_value(row, [ :url, :linkedin_url, :profile_url ])
    connected_on = find_column_value(row, [ :connected_on, :"connected on", :connection_date ])

    # Skip if no meaningful data
    if first_name.blank? && last_name.blank? && email.blank?
      return { skip: true }
    end

    {
      given_name: first_name&.strip,
      family_name: last_name&.strip,
      emails: email.present? ? email.strip : nil,
      organization: company&.strip,
      job_title: position&.strip,
      linkedin_url: linkedin_url&.strip,
      connected_on: connected_on&.strip,
      source: @custom_source || "linkedin",
      skip: false
    }
  end

  def find_column_value(row, possible_keys)
    possible_keys.each do |key|
      value = row[key]
      return value if value.present?
    end
    nil
  end

  def find_or_create_contact(contact_data)
    # Create a unique identifier for this LinkedIn contact
    uid = generate_linkedin_uid(contact_data)

    # Try to find existing contact by UID
    contact = @user.contacts.find_by(uid: uid)

    if contact
      # Update existing contact with new information
      update_contact_data(contact, contact_data)
    else
      # Create new contact
      # Build social profiles with LinkedIn URL
      social_profiles = []
      if contact_data[:linkedin_url].present?
        social_profiles << "LinkedIn: #{contact_data[:linkedin_url]}"
      end

      # Build notes with connection date
      notes_parts = []
      if contact_data[:connected_on].present?
        notes_parts << "Connected on LinkedIn: #{contact_data[:connected_on]}"
      end
      notes_parts << "Imported from LinkedIn Connections"

      contact = @user.contacts.create(
        uid: uid,
        given_name: contact_data[:given_name],
        family_name: contact_data[:family_name],
        emails: contact_data[:emails],
        organization: contact_data[:organization],
        job_title: contact_data[:job_title],
        social_profiles: social_profiles.join("\n"),
        notes: notes_parts.join("\n"),
        source: contact_data[:source],
        imported_at: Time.current
      )
    end

    contact
  end

  def generate_linkedin_uid(contact_data)
    # Create a unique identifier based on name and email
    identifier_parts = []
    identifier_parts << contact_data[:given_name] if contact_data[:given_name].present?
    identifier_parts << contact_data[:family_name] if contact_data[:family_name].present?
    identifier_parts << contact_data[:emails] if contact_data[:emails].present?

    base_string = identifier_parts.join("|").downcase
    "linkedin_#{Digest::MD5.hexdigest(base_string)}"
  end

  def update_contact_data(contact, new_data)
    # Update contact with new information, preserving existing data
    contact.given_name = new_data[:given_name] if new_data[:given_name].present? && contact.given_name.blank?
    contact.family_name = new_data[:family_name] if new_data[:family_name].present? && contact.family_name.blank?
    contact.organization = new_data[:organization] if new_data[:organization].present? && contact.organization.blank?
    contact.job_title = new_data[:job_title] if new_data[:job_title].present? && contact.job_title.blank?

    # Handle emails - merge if both exist
    if new_data[:emails].present?
      if contact.emails.present?
        existing_emails = contact.email_list
        new_email = new_data[:emails]
        unless existing_emails.include?(new_email)
          contact.emails = (existing_emails + [ new_email ]).join(", ")
        end
      else
        contact.emails = new_data[:emails]
      end
    end

    # Handle LinkedIn URL in social profiles
    if new_data[:linkedin_url].present?
      linkedin_entry = "LinkedIn: #{new_data[:linkedin_url]}"
      if contact.social_profiles.present?
        # Check if LinkedIn URL already exists
        unless contact.social_profiles.include?(new_data[:linkedin_url])
          contact.social_profiles = "#{contact.social_profiles}\n#{linkedin_entry}"
        end
      else
        contact.social_profiles = linkedin_entry
      end
    end

    # Handle connection date in notes
    if new_data[:connected_on].present?
      connection_note = "Connected on LinkedIn: #{new_data[:connected_on]}"
      if contact.notes.present?
        unless contact.notes.include?(connection_note)
          contact.notes = "#{contact.notes}\n#{connection_note}"
        end
      else
        contact.notes = connection_note
      end
    end

    contact.save
    contact
  end
end
