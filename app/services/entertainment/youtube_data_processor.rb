module Entertainment
  class YoutubeDataProcessor
  require 'json'

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
      # Read and parse the JSON file
      file_content = File.read(@file_path)
      youtube_data = JSON.parse(file_content)
      
      # Validate that it's an array
      unless youtube_data.is_a?(Array)
        raise "Invalid JSON format: Expected an array of watch history records"
      end

      # Process each record
      youtube_data.each_with_index do |record, index|
        process_record(record, index + 1)
      end

      {
        count: @imported_count,
        skipped: @skipped_count,
        duplicates: @duplicate_count,
        errors: @errors
      }
    rescue JSON::ParserError => e
      Rails.logger.error "YouTube JSON parsing error: #{e.message}"
      raise "Invalid JSON file: #{e.message}"
    rescue => e
      Rails.logger.error "YouTube JSON processing error: #{e.message}"
      raise e
    end
  end

  private

  def process_record(record, record_number)
    begin
      # Extract data from the record
      title = record['title']&.strip
      link = record['link']&.strip
      watch_date_str = record['watchDate']&.strip

      # Skip empty records
      if title.blank? || watch_date_str.blank?
        @skipped_count += 1
        return
      end

      # Parse the date
      date_consumed = parse_date(watch_date_str)
      unless date_consumed
        @errors << "Record #{record_number}: Invalid date format '#{watch_date_str}'. Expected format like 'Apr 17, 2012, 4:40:31 PM CDT'."
        @skipped_count += 1
        return
      end

      # Extract video ID from link if available
      video_id = extract_video_id(link) if link.present?

      # Check for existing record (to avoid duplicates)
      # We'll use title and date as the primary deduplication strategy
      # but also check video_id if available
      existing_conditions = { title: title, date_consumed: date_consumed }
      
      existing_record = @user.entertainment_contents.youtube.find_by(existing_conditions)

      if existing_record
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Prepare metadata
      metadata = {}
      metadata['video_id'] = video_id if video_id.present?
      metadata['link'] = link if link.present?

      # Create the entertainment content record
      @user.entertainment_contents.create!(
        content_type: 'youtube',
        title: title,
        date_consumed: date_consumed,
        source: 'YouTube',
        metadata: metadata.to_json,
        imported_at: Time.current
      )

      @imported_count += 1

    rescue => e
      @errors << "Record #{record_number}: #{e.message}"
      @skipped_count += 1
      Rails.logger.error "Error processing YouTube record #{record_number}: #{e.message}"
    end
  end

  def parse_date(date_str)
    # YouTube provides dates in format "Apr 17, 2012, 4:40:31 PM CDT"
    begin
      # Remove timezone abbreviation and parse
      cleaned_date = date_str.gsub(/\s+[A-Z]{3,4}$/, '')
      DateTime.strptime(cleaned_date, '%b %d, %Y, %I:%M:%S %p')
    rescue Date::Error, ArgumentError
      # Try alternative parsing strategies
      begin
        # Sometimes the format might be slightly different
        Date.parse(date_str)
      rescue Date::Error, ArgumentError
        nil
      end
    end
  end

  def extract_video_id(link)
    # Extract video ID from YouTube URL
    # Handles various YouTube URL formats:
    # https://www.youtube.com/watch?v=VIDEO_ID
    # https://youtu.be/VIDEO_ID
    # https://youtube.com/watch?v=VIDEO_ID
    return nil unless link.present?

    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/.*[?&]v=([a-zA-Z0-9_-]{11})/
    ]

    patterns.each do |pattern|
      match = link.match(pattern)
      return match[1] if match
    end

    nil
  end
end
end
