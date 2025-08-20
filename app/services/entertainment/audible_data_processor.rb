module Entertainment
  class AudibleDataProcessor
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
      Rails.logger.error "Audible CSV processing error: #{e.message}"
      raise e
    end
  end

  private

  def validate_headers(headers)
    required_headers = ['Product Name', 'Start Date', 'End Date']
    
    required_headers.each do |required_header|
      unless headers.include?(required_header)
        raise "Missing required header: #{required_header}. Found headers: #{headers.join(', ')}"
      end
    end
  end

  def process_row(row, row_number)
    begin
      product_name = row['Product Name']&.strip
      start_date_str = row['Start Date']&.strip
      end_date_str = row['End Date']&.strip
      
      # Extract additional metadata
      asin = row['ASIN']&.strip
      event_duration_ms = row['Event Duration Milliseconds']&.strip
      book_length_ms = row['Book Length Milliseconds']&.strip
      narration_speed = row['Narration Speed']&.strip
      delivery_type = row['Delivery Type']&.strip
      listening_mode = row['Listening Mode']&.strip

      # Skip empty rows
      if product_name.blank? || start_date_str.blank?
        @skipped_count += 1
        return
      end

      # Parse the dates (YYYY-MM-DD format)
      start_date = parse_date(start_date_str)
      end_date = parse_date(end_date_str) if end_date_str.present?
      
      unless start_date
        @errors << "Row #{row_number}: Invalid start date format '#{start_date_str}'. Expected YYYY-MM-DD format."
        @skipped_count += 1
        return
      end

      # Use start date as the date consumed
      date_consumed = start_date

      # Create metadata object
      metadata = {
        asin: asin,
        event_duration_ms: event_duration_ms&.to_i,
        book_length_ms: book_length_ms&.to_i,
        narration_speed: narration_speed&.to_f,
        delivery_type: delivery_type,
        listening_mode: listening_mode,
        start_date: start_date_str,
        end_date: end_date_str
      }.compact

      # Check for existing record (to avoid duplicates)
      # Use product name, date, and ASIN for uniqueness
      existing_record = @user.entertainment_contents.audible_books.find_by(
        title: product_name,
        date_consumed: date_consumed,
        metadata: metadata.to_json
      )

      if existing_record
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Create the entertainment content record
      @user.entertainment_contents.create!(
        content_type: 'audible_book',
        title: product_name,
        date_consumed: date_consumed,
        source: 'Audible',
        metadata: metadata.to_json,
        imported_at: Time.current
      )

      @imported_count += 1

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
      Rails.logger.error "Error processing Audible row #{row_number}: #{e.message}"
    end
  end

  def parse_date(date_str)
    # Audible provides dates in YYYY-MM-DD format (e.g., "2025-08-16")
    begin
      Date.strptime(date_str, '%Y-%m-%d')
    rescue Date::Error
      nil
    end
  end
end
end
