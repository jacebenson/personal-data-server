class NetflixDataProcessor
  require 'csv'

  def initialize(file_path, user)
    @file_path = file_path
    @user = user
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
    @errors = []
  end

  def process
    begin
      # Read the CSV file with comma separator
      csv_data = CSV.read(@file_path, headers: true, col_sep: ",")
      
      # Validate headers
      validate_headers(csv_data.headers)
      
      # Process each row
      csv_data.each_with_index do |row, index|
        process_row(row, index + 2) # +2 because CSV is 1-indexed and we skip header
      end

      {
        count: @imported_count,
        skipped: @skipped_count,
        duplicates: @duplicate_count,
        errors: @errors
      }
    rescue => e
      Rails.logger.error "Netflix CSV processing error: #{e.message}"
      raise e
    end
  end

  private

  def validate_headers(headers)
    required_headers = ['Title', 'Date']
    
    required_headers.each do |required_header|
      unless headers.include?(required_header)
        raise "Missing required header: #{required_header}. Found headers: #{headers.join(', ')}"
      end
    end
  end

  def process_row(row, row_number)
    begin
      title = row['Title']&.strip
      date_str = row['Date']&.strip

      # Skip empty rows
      if title.blank? || date_str.blank?
        @skipped_count += 1
        return
      end

      # Parse the date (MM/DD/YYYY format)
      date_consumed = parse_date(date_str)
      unless date_consumed
        @errors << "Row #{row_number}: Invalid date format '#{date_str}'. Expected MM/DD/YYYY format."
        @skipped_count += 1
        return
      end

      # Check for existing record (to avoid duplicates)
      existing_record = @user.entertainment_contents.netflix.find_by(
        title: title,
        date_consumed: date_consumed
      )

      if existing_record
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Create the entertainment content record
      @user.entertainment_contents.create!(
        content_type: 'netflix',
        title: title,
        date_consumed: date_consumed,
        source: 'Netflix',
        imported_at: Time.current
      )

      @imported_count += 1

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
      Rails.logger.error "Error processing Netflix row #{row_number}: #{e.message}"
    end
  end

  def parse_date(date_str)
    # Netflix provides dates in M/D/YY format (e.g., "6/7/25")
    begin
      Date.strptime(date_str, '%m/%d/%y')
    rescue Date::Error
      # Try alternative formats just in case
      begin
        Date.strptime(date_str, '%m/%d/%Y')
      rescue Date::Error
        nil
      end
    end
  end
end
