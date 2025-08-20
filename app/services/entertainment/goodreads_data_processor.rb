require 'csv'

module Entertainment
  class GoodreadsDataProcessor
  attr_reader :errors, :processed_count, :skipped_count

  def initialize(file_path, user)
    @file_path = file_path
    @user = user
    @errors = []
    @processed_count = 0
    @skipped_count = 0
  end

  def process
    return { success: false, errors: @errors } unless valid_file?

    begin
      # Read CSV with proper encoding handling
      csv_content = File.read(@file_path, encoding: 'UTF-8')
      
      # Handle BOM if present
      csv_content = csv_content.delete("\xEF\xBB\xBF")
      
      CSV.parse(csv_content, headers: true, liberal_parsing: true) do |row|
        process_row(row)
      end

      return {
        success: @errors.empty?,
        count: @processed_count,
        skipped: @skipped_count,
        errors: @errors
      }
    rescue CSV::MalformedCSVError => e
      @errors << "Invalid CSV format: #{e.message}"
      return { success: false, errors: @errors }
    rescue StandardError => e
      @errors << "Error processing file: #{e.message}"
      return { success: false, errors: @errors }
    end
  end

  private

  def valid_file?
    unless File.exist?(@file_path)
      @errors << "File not found"
      return false
    end

    unless File.readable?(@file_path)
      @errors << "File is not readable"
      return false
    end

    # Check file size (limit to 50MB)
    if File.size(@file_path) > 50.megabytes
      @errors << "File is too large (maximum 50MB)"
      return false
    end

    true
  end

  def process_row(row)
    # Skip empty rows
    return if row.to_h.values.all?(&:blank?)

    begin
      # Parse the data from the row
      book_data = parse_book_data(row)
      
      # Skip if we couldn't parse essential data
      return if book_data[:title].blank?

      # Check for existing record to avoid duplicates
      existing_record = EntertainmentContent.where(
        user: @user,
        content_type: 'goodreads',
        title: book_data[:title],
        author: book_data[:author]
      ).first

      if existing_record
        @skipped_count += 1
        return
      end

      # Create new record
      EntertainmentContent.create!(
        user: @user,
        content_type: 'goodreads',
        title: book_data[:title],
        author: book_data[:author],
        my_rating: book_data[:my_rating],
        exclusive_shelf: book_data[:exclusive_shelf],
        date_read: book_data[:date_read],
        date_consumed: book_data[:date_read] || Time.current, # Use date_read or current time as fallback
        source: 'goodreads', # Set default source for goodreads
        number_of_pages: book_data[:number_of_pages],
        year_published: book_data[:year_published],
        original_publication_year: book_data[:original_publication_year],
        isbn: book_data[:isbn],
        isbn13: book_data[:isbn13],
        book_id: book_data[:book_id],
        average_rating: book_data[:average_rating],
        publisher: book_data[:publisher],
        binding: book_data[:binding],
        additional_authors: book_data[:additional_authors],
        created_at: Time.current,
        updated_at: Time.current
      )

      @processed_count += 1

    rescue StandardError => e
      @errors << "Error processing row: #{e.message} - Data: #{row.to_h.inspect}"
    end
  end

  def parse_book_data(row)
    {
      book_id: safe_integer(row['Book Id']),
      title: clean_string(row['Title']),
      author: clean_string(row['Author']),
      additional_authors: clean_string(row['Additional Authors']),
      isbn: clean_string(row['ISBN']),
      isbn13: clean_string(row['ISBN13']),
      my_rating: safe_integer(row['My Rating']),
      average_rating: safe_float(row['Average Rating']),
      publisher: clean_string(row['Publisher']),
      binding: clean_string(row['Binding']),
      number_of_pages: safe_integer(row['Number of Pages']),
      year_published: safe_integer(row['Year Published']),
      original_publication_year: safe_integer(row['Original Publication Year']),
      date_read: parse_date(row['Date Read']),
      exclusive_shelf: normalize_shelf(row['Exclusive Shelf'])
    }
  end

  def clean_string(value)
    return nil if value.blank?
    
    # Remove quotes and clean up the string, including Excel-style formulas
    cleaned = value.to_s.strip
    cleaned = cleaned.gsub(/^["']|["']$/, '') # Remove leading/trailing quotes
    cleaned = cleaned.gsub(/^=["']|["']$/, '') # Remove Excel formula quotes like ="value"
    cleaned = cleaned.gsub(/^=/, '') # Remove leading = from Excel formulas
    cleaned.blank? ? nil : cleaned
  end

  def safe_integer(value)
    return nil if value.blank?
    
    # Handle cases where the value might be a string like "=123" (Excel formula)
    cleaned = value.to_s.gsub(/[^0-9-]/, '')
    return nil if cleaned.blank?
    
    begin
      Integer(cleaned)
    rescue ArgumentError
      nil
    end
  end

  def safe_float(value)
    return nil if value.blank?
    
    begin
      Float(value.to_s)
    rescue ArgumentError
      nil
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # Handle various date formats
    date_formats = [
      '%Y/%m/%d',   # 2023/12/25
      '%Y-%m-%d',   # 2023-12-25
      '%m/%d/%Y',   # 12/25/2023
      '%m-%d-%Y',   # 12-25-2023
      '%Y/%m',      # 2023/12 (for month only)
      '%Y-%m',      # 2023-12
      '%Y'          # 2023 (for year only, will default to Jan 1)
    ]

    date_formats.each do |format|
      begin
        return Date.strptime(date_string.strip, format)
      rescue ArgumentError
        next
      end
    end

    # If no format works, try natural language parsing
    begin
      return Date.parse(date_string.strip)
    rescue ArgumentError
      return nil
    end
  end

  def normalize_shelf(shelf)
    return nil if shelf.blank?
    
    # Normalize common shelf names
    normalized = shelf.to_s.strip.downcase
    
    case normalized
    when 'read', 'finished', 'completed'
      'read'
    when 'currently-reading', 'reading', 'current'
      'currently-reading'
    when 'to-read', 'want-to-read', 'wishlist', 'tbr'
      'to-read'
    else
      normalized
    end
  end

  def self.expected_headers
    [
      'Book Id',
      'Title', 
      'Author',
      'Author l-f',
      'Additional Authors',
      'ISBN',
      'ISBN13',
      'My Rating',
      'Average Rating',
      'Publisher',
      'Binding',
      'Number of Pages',
      'Year Published',
      'Original Publication Year',
      'Date Read',
      'Date Added',
      'Bookshelves',
      'Bookshelves with positions',
      'Exclusive Shelf',
      'My Review',
      'Spoiler',
      'Private Notes',
      'Read Count',
      'Recommended For',
      'Recommended By',
      'Owned Copies',
      'Original Purchase Date',
      'Original Purchase Location',
      'Condition',
      'Condition Description',
      'BCID'
    ]
  end

  def self.validate_headers(file_path)
    return false unless File.exist?(file_path)

    begin
      csv_content = File.read(file_path, encoding: 'UTF-8')
      csv_content = csv_content.delete("\xEF\xBB\xBF")
      
      csv_data = CSV.parse(csv_content, headers: true, liberal_parsing: true)
      first_row = csv_data.first
      return { valid: false, error: "No data rows found" } unless first_row
      
      headers = first_row.headers.map(&:strip)
      
      # Check for essential headers
      required_headers = ['Title', 'Author', 'Exclusive Shelf']
      missing_headers = required_headers - headers
      
      return {
        valid: missing_headers.empty?,
        missing_headers: missing_headers,
        found_headers: headers,
        total_rows: csv_data.count
      }
    rescue StandardError => e
      return {
        valid: false,
        error: e.message
      }
    end
  end
end
end
