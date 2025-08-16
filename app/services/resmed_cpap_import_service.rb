class ResmedCpapImportService
  attr_reader :errors, :summary

  def initialize
    @errors = []
    @summary = {
      sleep_sessions: 0,
      patients: 0,
      skipped: 0
    }
  end

  def import_from_csv(file_path)
    Rails.logger.info "Starting ResMed CPAP CSV import from #{file_path}"
    
    begin
      require 'csv'
      
      # Get or create the patient (for now, using first patient like the main health system)
      patient = HealthPatient.first
      
      unless patient
        @errors << "No patient found. Please import health data with patient information first."
        return false
      end

      rows_processed = 0
      
      CSV.foreach(file_path, headers: true, header_converters: :symbol) do |row|
        rows_processed += 1
        
        begin
          process_sleep_record(row, patient)
        rescue => e
          Rails.logger.error "Error processing ResMed CPAP row #{rows_processed}: #{e.message}"
          @errors << "Row #{rows_processed}: #{e.message}"
        end
      end

      Rails.logger.info "ResMed CPAP import completed. Processed #{rows_processed} rows."
      Rails.logger.info "Summary: #{@summary}"
      
      return @errors.empty?
      
    rescue => e
      Rails.logger.error "ResMed CPAP import failed: #{e.message}"
      @errors << "Import failed: #{e.message}"
      return false
    end
  end

  private

  def process_sleep_record(row, patient)
    session_date = row[:session_date]
    return if session_date.blank?

    # Parse the ISO 8601 date format
    begin
      parsed_date = Date.parse(session_date).strftime('%Y-%m-%d')
    rescue
      Rails.logger.warn "Could not parse session date: #{session_date}"
      return
    end

    device_serial = row[:fg_serial_no]
    usage_hours = row[:usage_hours]
    
    # Skip records without essential data
    return if usage_hours.blank? || usage_hours.to_f <= 0

    # Check if we already have this sleep session
    existing_session = HealthSleepData.find_by(
      health_patient: patient,
      session_date: parsed_date,
      device_serial: device_serial
    )

    if existing_session
      # Update existing record if any data has changed
      update_attributes = build_sleep_attributes(row)
      
      if should_update_session?(existing_session, update_attributes)
        existing_session.update(update_attributes)
        @summary[:sleep_sessions] += 1
        Rails.logger.debug "Updated sleep session for #{parsed_date}"
      else
        @summary[:skipped] += 1
      end
    else
      # Create new sleep session record
      sleep_attributes = {
        health_patient: patient,
        session_date: parsed_date,
        device_serial: device_serial
      }.merge(build_sleep_attributes(row))

      sleep_data = HealthSleepData.create(sleep_attributes)
      
      if sleep_data.persisted?
        @summary[:sleep_sessions] += 1
        Rails.logger.debug "Created sleep session for #{parsed_date}: #{usage_hours} hours"
      else
        Rails.logger.warn "Failed to save sleep data: #{sleep_data.errors.full_messages.join(', ')}"
      end
    end
  end

  def build_sleep_attributes(row)
    {
      usage_hours: safe_decimal(row[:usage_hours]),
      sleep_score: safe_integer(row[:sleep_score]),
      ahi_score: safe_decimal(row[:ahi_score]),
      leak_score: safe_integer(row[:leak_score]),
      mask_score: safe_integer(row[:mask_score]),
      usage_score: safe_integer(row[:usage_score]),
      mask_session_count: safe_integer(row[:mask_session_count]),
      ahi: safe_decimal(row[:ahi]),
      leak_50_percentile: safe_decimal(row[:leak_50_percentile]),
      leak_70_percentile: safe_decimal(row[:leak_70_percentile]),
      leak_95_percentile: safe_decimal(row[:leak_95_percentile]),
      mode: row[:mode]&.strip
    }
  end

  def should_update_session?(existing_session, new_attributes)
    # Check if any meaningful data has changed
    new_attributes.any? do |key, new_value|
      existing_value = existing_session.send(key)
      
      # Handle decimal comparisons with tolerance
      if new_value.is_a?(Numeric) && existing_value.is_a?(Numeric)
        (new_value - existing_value).abs > 0.01
      else
        existing_value != new_value
      end
    end
  end

  def safe_decimal(value)
    return nil if value.blank?
    value.to_f.round(2) rescue nil
  end

  def safe_integer(value)
    return nil if value.blank?
    value.to_i rescue nil
  end
end
