require 'csv'

class LinkedinMessagesProcessor
  attr_reader :file, :user, :results

  def initialize(file, user)
    @file = file
    @user = user
    @results = { imported: 0, skipped: 0, errors: [], duplicates: 0 }
  end

  def process
    # Handle file encoding issues that are common with LinkedIn exports
    content = File.read(file.path, encoding: 'UTF-8')

    # Fix common line ending issues
    content = content.gsub(/\r\n/, "\n").gsub(/\r/, "\n")

    # Parse CSV with proper options
    csv_options = {
      headers: true,
      encoding: 'UTF-8',
      liberal_parsing: true,
      quote_char: '"',
      col_sep: ','
    }

    CSV.parse(content, **csv_options) do |row|
      process_row(row.to_h)
    end

    results
  rescue => e
    results[:errors] << "Failed to process file: #{e.message}"
    results
  end

  private

  def process_row(row_data)
    # Skip empty rows
    return if row_data.values.all?(&:blank?)

    # Extract and clean data from the CSV row
    message_data = extract_message_data(row_data)

    # Skip if essential data is missing
    unless valid_message_data?(message_data)
      results[:skipped] += 1
      return
    end

    # Check for duplicates
    if duplicate_exists?(message_data)
      results[:duplicates] += 1
      results[:skipped] += 1
      return
    end

    # Create the LinkedIn message
    create_linkedin_message(message_data)
    results[:imported] += 1

  rescue => e
    results[:errors] << "Row processing error: #{e.message}"
    results[:skipped] += 1
  end

  def extract_message_data(row)
    # Map CSV columns to our database fields
    # Handle variations in column names that LinkedIn might use
    {
      conversation_id: clean_field(row['CONVERSATION ID'] || row['Conversation ID']),
      conversation_title: clean_field(row['CONVERSATION TITLE'] || row['Conversation Title']),
      from_name: clean_field(row['FROM'] || row['From']),
      from_profile_url: clean_field(row['SENDER PROFILE URL'] || row['Sender Profile URL']),
      to_name: clean_field(row['TO'] || row['To']),
      to_profile_url: clean_field(row['RECIPIENT PROFILE URLS'] || row['Recipient Profile URLs']),
      sent_at: parse_date(row['DATE'] || row['Date']),
      subject: clean_field(row['SUBJECT'] || row['Subject']),
      content: clean_field(row['CONTENT'] || row['Content']),
      folder: clean_field(row['FOLDER'] || row['Folder']),
      attachments: clean_field(row['ATTACHMENTS'] || row['Attachments']),
      is_draft: parse_boolean(row['IS MESSAGE DRAFT'] || row['Is Message Draft'])
    }
  end

  def clean_field(value)
    return nil if value.blank?
    value.to_s.strip
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # LinkedIn typically uses "YYYY-MM-DD HH:MM:SS UTC" format
    DateTime.parse(date_string.to_s)
  rescue
    # Fallback to current time if parsing fails
    DateTime.current
  end

  def parse_boolean(value)
    return false if value.blank?

    value.to_s.downcase.in?(['yes', 'true', '1', 'y'])
  end

  def valid_message_data?(data)
    # Essential fields that must be present
    data[:conversation_id].present? &&
    data[:from_name].present? &&
    data[:sent_at].present?
  end

  def duplicate_exists?(data)
    # Check if a message with the same key attributes already exists
    user.linkedin_messages.exists?(
      conversation_id: data[:conversation_id],
      from_name: data[:from_name],
      sent_at: data[:sent_at],
      content: data[:content]
    )
  end

  def create_linkedin_message(data)
    user.linkedin_messages.create!(
      conversation_id: data[:conversation_id],
      conversation_title: data[:conversation_title],
      from_name: data[:from_name],
      from_profile_url: data[:from_profile_url],
      to_name: data[:to_name],
      to_profile_url: data[:to_profile_url],
      sent_at: data[:sent_at],
      subject: data[:subject],
      content: data[:content],
      folder: data[:folder] || 'INBOX',
      attachments: data[:attachments],
      is_draft: data[:is_draft] || false
    )
  end
end
