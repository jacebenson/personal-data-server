require "icalendar"
require "net/http"
require "uri"
require "open-uri"

class IcsProcessor
  def initialize(source, user)
    @source = source  # Can be a file path, uploaded file, or URL
    @user = user
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
    @errors = []
    @calendar_name = nil
  end

  def process
    Rails.logger.info "Starting ICS processing for user #{@user.id}"
    Rails.logger.info "Processing source: #{@source.class} - #{source_info}"

    begin
      # Get ICS content based on source type
      ics_content = get_ics_content

      # Parse ICS content
      calendars = Icalendar::Calendar.parse(ics_content)

      if calendars.empty?
        @errors << "No valid calendars found in ICS file"
        return result_summary
      end

      # Process each calendar
      calendars.each_with_index do |calendar, calendar_index|
        process_calendar(calendar, calendar_index)
      end

      Rails.logger.info "✅ ICS processing completed"
      Rails.logger.info "📊 Final stats: #{@imported_count} imported, #{@skipped_count} skipped, #{@errors.length} errors"

      result_summary

    rescue => e
      Rails.logger.error "❌ Error processing ICS: #{e.message}"
      @errors << e.message
      result_summary
    end
  end

  private

  def get_ics_content
    case @source
    when String
      if @source.start_with?("http")
        # URL source
        download_from_url(@source)
      else
        # File path
        File.read(@source)
      end
    when ActionDispatch::Http::UploadedFile, Tempfile
      # Uploaded file
      @source.read
    else
      raise "Unsupported source type: #{@source.class}"
    end
  end

  def download_from_url(url)
    Rails.logger.info "Downloading ICS from URL: #{url}"

    # Use OpenURI for simpler HTTP handling with redirects
    content = URI.open(url) do |file|
      file.read
    end

    Rails.logger.info "Downloaded #{content.bytesize} bytes from #{url}"
    content
  rescue => e
    raise "Failed to download ICS from URL: #{e.message}"
  end

  def source_info
    case @source
    when String
      if @source.start_with?("http")
        @source
      else
        File.basename(@source)
      end
    when ActionDispatch::Http::UploadedFile
      @source.original_filename
    else
      @source.to_s
    end
  end

  def process_calendar(calendar, calendar_index)
    # Extract calendar name
    calendar_name = extract_calendar_name(calendar, calendar_index)
    @calendar_name = calendar_name

    Rails.logger.info "Processing calendar: #{calendar_name} with #{calendar.events.length} events"

    # Process each event in the calendar
    calendar.events.each_with_index do |event, event_index|
      process_event(event, calendar_name, event_index)
    end
  end

  def extract_calendar_name(calendar, index)
    # Try to get calendar name from various properties
    name = calendar.x_wr_calname&.first&.to_s ||
           calendar.prodid&.to_s ||
           "Calendar #{index + 1}"

    # Clean up the name
    name = name.strip
    name = name.gsub(/[^\w\s\-_]/, "").strip if name.present?
    name = "Unnamed Calendar" if name.blank?

    # If source is a URL, try to extract domain
    if @source.is_a?(String) && @source.start_with?("http")
      begin
        domain = URI.parse(@source).host
        name = "#{name} (#{domain})" if domain
      rescue
        # Ignore URI parsing errors
      end
    end

    name
  end

  def process_event(event, calendar_name, index)
    begin
      # Extract event details
      uid = extract_uid(event, index)
      summary = extract_summary(event)
      description = extract_description(event)
      location = extract_location(event)
      start_time, end_time, all_day = extract_time_info(event)
      recurrence_rule = extract_recurrence_rule(event)
      categories = extract_categories(event)
      status = extract_status(event)
      organizer_email, organizer_name = extract_organizer(event)
      attendee_emails = extract_attendees(event)

      # Check for existing event to prevent duplicates
      existing_event = @user.calendar_events.find_by(uid: uid, calendar_name: calendar_name)

      if existing_event
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Create new calendar event record
      @user.calendar_events.create!(
        uid: uid,
        summary: summary,
        description: description,
        location: location,
        start_time: start_time,
        end_time: end_time,
        all_day_event: all_day,
        calendar_name: calendar_name,
        recurrence_rule: recurrence_rule,
        categories: categories,
        status: status,
        organizer_email: organizer_email,
        organizer_name: organizer_name,
        attendee_emails: attendee_emails
      )

      @imported_count += 1

    rescue => e
      Rails.logger.warn "Failed to process event #{index + 1}: #{e.message}" if @errors.length < 10
      @errors << "Event #{index + 1} processing error: #{e.message}"
      @skipped_count += 1
    end
  end

  def extract_uid(event, index)
    uid = event.uid&.to_s
    return uid if uid.present?

    # Generate a unique ID based on event details
    summary_str = event.summary || "no-summary"
    start_str = event.dtstart&.to_s || Time.current.to_s
    location_str = event.location || "no-location"

    Digest::MD5.hexdigest("#{summary_str}-#{start_str}-#{location_str}-#{index}")
  end

  def extract_summary(event)
    summary = event.summary&.to_s&.strip
    return summary if summary.present?
    "(No Title)"
  end

  def extract_description(event)
    description = event.description&.to_s&.strip
    # Limit description length to prevent database issues
    description = description[0, 10000] if description && description.length > 10000
    description
  end

  def extract_location(event)
    event.location&.to_s&.strip
  end

  def extract_time_info(event)
    start_time = nil
    end_time = nil
    all_day = false

    if event.dtstart
      if event.dtstart.respond_to?(:to_time)
        start_time = event.dtstart.to_time
      elsif event.dtstart.is_a?(Date)
        # All-day event
        start_time = event.dtstart.to_time.beginning_of_day
        all_day = true
      else
        start_time = Time.parse(event.dtstart.to_s)
      end
    end

    if event.dtend
      if event.dtend.respond_to?(:to_time)
        end_time = event.dtend.to_time
      elsif event.dtend.is_a?(Date)
        end_time = event.dtend.to_time.beginning_of_day
      else
        end_time = Time.parse(event.dtend.to_s)
      end
    elsif event.duration
      # Calculate end time from duration
      if start_time
        duration_seconds = event.duration.to_i
        end_time = start_time + duration_seconds.seconds
      end
    end

    # Default start time if none provided
    start_time ||= Time.current

    [ start_time, end_time, all_day ]
  end

  def extract_recurrence_rule(event)
    event.rrule&.first&.to_s
  end

  def extract_categories(event)
    if event.categories && event.categories.any?
      event.categories.map(&:to_s).join(", ")
    else
      nil
    end
  end

  def extract_status(event)
    event.status&.to_s&.downcase
  end

  def extract_organizer(event)
    return [ nil, nil ] unless event.organizer

    organizer = event.organizer
    email = nil
    name = nil

    if organizer.respond_to?(:to_s)
      organizer_str = organizer.to_s

      # Parse "MAILTO:email@domain.com" format
      if organizer_str.match(/^MAILTO:(.+@.+)$/i)
        email = $1.strip
      end
    end

    # Try to get CN (Common Name) parameter
    if organizer.respond_to?(:params) && organizer.params["CN"]
      name = organizer.params["CN"].to_s.strip
    end

    [ email, name ]
  end

  def extract_attendees(event)
    return nil unless event.attendee && event.attendee.any?

    attendees = []

    event.attendee.each do |attendee|
      if attendee.respond_to?(:to_s)
        attendee_str = attendee.to_s

        # Parse "MAILTO:email@domain.com" format
        if attendee_str.match(/^MAILTO:(.+@.+)$/i)
          attendees << $1.strip
        end
      end
    end

    attendees.any? ? attendees.join(", ") : nil
  end

  def result_summary
    {
      count: @imported_count,
      skipped: @skipped_count,
      duplicates: @duplicate_count,
      errors: @errors,
      calendar_name: @calendar_name
    }
  end
end
