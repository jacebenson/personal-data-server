module Entertainment
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
      # Use epoch timestamp for reliable date comparison with 1-day tolerance
      date_epoch = date_consumed.to_time.to_i
      one_day_seconds = 86400  # 24 hours * 60 minutes * 60 seconds
      
      # Find records with same title and date within 1 day
      existing_record = @user.entertainment_contents.netflix.where(title: title).find do |record|
        record_epoch = record.date_consumed.to_time.to_i
        epoch_difference = (record_epoch - date_epoch).abs
        epoch_difference <= one_day_seconds
      end

      if existing_record
        Rails.logger.info "Netflix duplicate found: '#{title}' on #{date_consumed} (existing ID: #{existing_record.id})"
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      Rails.logger.info "Netflix creating new record: '#{title}' on #{date_consumed}"

      # Create the entertainment content record
      new_record = @user.entertainment_contents.create!(
        content_type: 'netflix',
        title: title,
        date_consumed: date_consumed,
        source: 'Netflix',
        imported_at: Time.current
      )

      Rails.logger.info "Netflix record created: '#{title}' on #{date_consumed} (ID: #{new_record.id})"
      @imported_count += 1

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
      Rails.logger.error "Error processing Netflix row #{row_number}: #{e.message}"
    end
  end

  def parse_date(date_str)
    # Netflix provides dates in M/D/YY format (e.g., "6/7/25")
    # Split the date and parse manually to avoid format issues
    begin
      parts = date_str.split('/')
      return nil unless parts.length == 3
      
      month = parts[0].to_i
      day = parts[1].to_i
      year = parts[2].to_i
      
      # Handle 2-digit years (convert to 4-digit)
      if year < 100
        year += year < 50 ? 2000 : 1900
      end
      
      # Create date and return it
      Date.new(year, month, day)
    rescue => e
      puts "Error parsing date '#{date_str}': #{e.message}"
      nil
    end
  end
end
end
