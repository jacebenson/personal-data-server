class AudibleLibraryProcessor
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
      Rails.logger.error "Audible Library CSV processing error: #{e.message}"
      raise e
    end
  end

  private

  def validate_headers(headers)
    required_headers = ['Product Name', 'ASIN', 'Date Added']
    
    required_headers.each do |required_header|
      unless headers.include?(required_header)
        raise "Missing required header: #{required_header}. Found headers: #{headers.join(', ')}"
      end
    end
  end

  def process_row(row, row_number)
    begin
      product_name = row['Product Name']&.strip
      asin = row['ASIN']&.strip
      date_added_str = row['Date Added']&.strip
      
      # Extract additional metadata
      downloaded = row['Downloaded']&.strip
      deleted = row['Deleted']&.strip
      delete_by = row['Delete By']&.strip
      date_deleted_str = row['Date Deleted']&.strip
      public = row['Public']&.strip
      streamed = row['Streamed']&.strip
      preorder = row['Preorder']&.strip
      downloads = row['Downloads']&.strip
      date_first_downloaded_str = row['Date First Downloaded']&.strip
      order_number = row['Order Number']&.strip
      origin_type = row['Origin Type']&.strip

      # Skip empty rows
      if product_name.blank? || asin.blank? || date_added_str.blank?
        @skipped_count += 1
        return
      end

      # Parse the dates (YYYY-MM-DD format)
      date_added = parse_date(date_added_str)
      date_deleted = parse_date(date_deleted_str) if date_deleted_str.present? && date_deleted_str != "Not Available"
      date_first_downloaded = parse_date(date_first_downloaded_str) if date_first_downloaded_str.present? && date_first_downloaded_str != "Not Available"
      
      unless date_added
        @errors << "Row #{row_number}: Invalid date added format '#{date_added_str}'. Expected YYYY-MM-DD format."
        @skipped_count += 1
        return
      end

      # Create metadata object
      metadata = {
        asin: asin,
        downloaded: downloaded,
        deleted: deleted,
        delete_by: delete_by,
        date_deleted: date_deleted&.strftime('%Y-%m-%d'),
        public: public,
        streamed: streamed,
        preorder: preorder,
        downloads: downloads&.to_i,
        date_first_downloaded: date_first_downloaded&.strftime('%Y-%m-%d'),
        order_number: order_number,
        origin_type: origin_type,
        date_added: date_added_str
      }.compact

      # Check for existing record (to avoid duplicates)
      # Use ASIN and date added for uniqueness since these should be unique per library item
      existing_record = @user.entertainment_contents.where(
        content_type: 'audible_library',
        metadata: metadata.select { |k, v| k.in?([:asin, :date_added]) }.to_json
      ).first

      if existing_record
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Create the entertainment content record
      @user.entertainment_contents.create!(
        content_type: 'audible_library',
        title: product_name,
        date_consumed: date_added, # Use date added as the date consumed for library items
        source: 'Audible Library',
        metadata: metadata.to_json,
        imported_at: Time.current
      )

      @imported_count += 1

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
      Rails.logger.error "Error processing Audible Library row #{row_number}: #{e.message}"
    end
  end

  def parse_date(date_str)
    # Audible provides dates in YYYY-MM-DD format (e.g., "2025-07-06")
    begin
      Date.strptime(date_str, '%Y-%m-%d')
    rescue Date::Error
      nil
    end
  end
end
