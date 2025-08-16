class ShotsyImportService
  attr_reader :errors, :summary

  def initialize
    @errors = []
    @summary = {
      vital_signs: 0,
      medications: 0,
      patients: 0,
      skipped: 0
    }
  end

  def import_from_csv(file_path)
    Rails.logger.info "Starting Shotsy CSV import from #{file_path}"
    
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
          process_shotsy_row(row, patient)
        rescue => e
          Rails.logger.error "Error processing Shotsy row #{rows_processed}: #{e.message}"
          @errors << "Row #{rows_processed}: #{e.message}"
        end
      end

      Rails.logger.info "Shotsy import completed. Processed #{rows_processed} rows."
      Rails.logger.info "Summary: #{@summary}"
      
      return @errors.empty?
      
    rescue => e
      Rails.logger.error "Shotsy import failed: #{e.message}"
      @errors << "Import failed: #{e.message}"
      return false
    end
  end

  private

  def process_shotsy_row(row, patient)
    date = row[:date]
    return if date.blank?

    # Process weight data if present
    process_weight_data(row, patient, date)
    
    # Process medication data if present
    process_medication_data(row, patient, date)
  end

  def process_weight_data(row, patient, date)
    weight_lbs = row[:recorded_weight_lbs]
    return if weight_lbs.blank?

    # Convert pounds to kilograms for consistency with health system
    # 1 lb = 0.453592 kg, so divide lbs by 2.20462 to get kg
    weight_kg = weight_lbs.to_f / 2.20462
    
    # Check if we already have vital signs for this date
    existing_vital_sign = HealthVitalSign.find_by(
      health_patient: patient,
      measurement_date: date
    )

    if existing_vital_sign
      # Update existing record if weight is different
      if existing_vital_sign.weight.nil? || existing_vital_sign.weight != weight_kg.round(2)
        existing_vital_sign.update(weight: weight_kg.round(2))
        @summary[:vital_signs] += 1
        Rails.logger.debug "Updated weight for #{date}: #{weight_lbs} lbs (#{weight_kg.round(2)} kg)"
      else
        @summary[:skipped] += 1
      end
    else
      # Create new vital sign record
      vital_sign = HealthVitalSign.create(
        health_patient: patient,
        measurement_date: date,
        weight: weight_kg.round(2)
      )
      
      if vital_sign.persisted?
        @summary[:vital_signs] += 1
        Rails.logger.debug "Created weight record for #{date}: #{weight_lbs} lbs (#{weight_kg.round(2)} kg)"
      else
        Rails.logger.warn "Failed to save weight record: #{vital_sign.errors.full_messages.join(', ')}"
      end
    end
  end

  def process_medication_data(row, patient, date)
    shot_name = row[:shot]
    return if shot_name.blank?

    avg_level = row[:avg_level_mg]
    shot_time = row[:time]
    site = row[:site]
    pain_level = row[:pain_level]
    taken = row[:taken]
    shot_notes = row[:shot_notes]

    # Extract medication name and dosage
    medication_name, dosage = extract_medication_info(shot_name)
    return if medication_name.blank?

    # For GLP-1 medications, we want to track each injection as a separate event
    # rather than one ongoing "active" medication, since dosages change over time
    
    # Check if this exact injection already exists for this date
    existing_medication = HealthMedication.find_by(
      health_patient: patient,
      medication_name: medication_name,
      dosage: dosage,
      start_date: date
    )

    if existing_medication
      # Update the existing record with any new information
      update_attributes = {}
      update_attributes[:route] = "Subcutaneous injection" if site.present?
      update_attributes[:status] = taken&.downcase == "yes" ? "completed" : "missed"
      
      if update_attributes.any?
        existing_medication.update(update_attributes)
      end
      
      @summary[:skipped] += 1
    else
      # Create new medication record for this specific injection
      medication_attributes = {
        health_patient: patient,
        medication_name: medication_name,
        dosage: dosage,
        start_date: date,
        end_date: date, # Single injection, so start and end are the same
        status: taken&.downcase == "yes" ? "completed" : "missed",
        route: "Subcutaneous injection",
        frequency: "Single injection" # This represents one injection, not ongoing
      }
      
      # Add prescriber info to indicate this is self-administered
      medication_attributes[:prescriber] = "Self-administered (Shotsy tracking)"

      medication = HealthMedication.create(medication_attributes)
      
      if medication.persisted?
        @summary[:medications] += 1
        Rails.logger.debug "Created injection record: #{medication_name} #{dosage} on #{date}"
      else
        Rails.logger.warn "Failed to save medication: #{medication.errors.full_messages.join(', ')}"
      end
    end

    # Create encounter/note if there are additional details
    create_shotsy_encounter(row, patient, date) if should_create_encounter?(row)
  end

  def extract_medication_info(shot_name)
    # Parse medication name and dosage from shot name
    # Examples: "Semaglutide 0.25mg", "Ozempic 0.5mg"
    if shot_name.match(/^(.+?)\s+(\d+(?:\.\d+)?mg)$/i)
      medication_name = $1.strip
      dosage = $2
      [medication_name, dosage]
    else
      [shot_name, ""]
    end
  end

  def should_create_encounter?(row)
    # Create encounter if there are notes, pain levels, or side effects documented
    [row[:shot_notes], row[:pain_level], row[:food_noise], 
     row[:heartburn], row[:nausea], row[:suppressed_appetite], 
     row[:day_notes]].any?(&:present?)
  end

  def create_shotsy_encounter(row, patient, date)
    # Create an encounter record to capture the injection details and tracking data
    reason_parts = []
    
    # Build the main reason based on the shot information
    if row[:shot].present?
      reason_parts << "#{row[:shot]} injection"
    else
      reason_parts << "GLP-1 injection tracking"
    end
    
    reason_parts << "Pain level: #{row[:pain_level]}" if row[:pain_level].present?
    
    # Document side effects
    side_effects = []
    side_effects << "Food noise reported" if row[:food_noise].present? && row[:food_noise].downcase != "no"
    side_effects << "Heartburn reported" if row[:heartburn].present? && row[:heartburn].downcase != "no"
    side_effects << "Nausea reported" if row[:nausea].present? && row[:nausea].downcase != "no"
    side_effects << "Suppressed appetite" if row[:suppressed_appetite].present? && row[:suppressed_appetite].downcase != "no"
    
    reason_parts.concat(side_effects)

    # Add notes and detailed tracking information
    notes_parts = []
    notes_parts << "Shot notes: #{row[:shot_notes]}" if row[:shot_notes].present?
    notes_parts << "Day notes: #{row[:day_notes]}" if row[:day_notes].present?
    notes_parts << "Injection site: #{row[:site]}" if row[:site].present?
    notes_parts << "Injection time: #{row[:time]}" if row[:time].present?
    notes_parts << "Average level: #{row[:avg_level_mg]} mg" if row[:avg_level_mg].present?
    notes_parts << "Taken: #{row[:taken]}" if row[:taken].present?

    # Additional tracking data
    if row[:calories].present? || row[:protein_g].present?
      nutrition_info = []
      nutrition_info << "Calories: #{row[:calories]}" if row[:calories].present?
      nutrition_info << "Protein: #{row[:protein_g]}g" if row[:protein_g].present?
      notes_parts << "Nutrition: #{nutrition_info.join(', ')}"
    end

    encounter_notes = notes_parts.join("\n")

    # Don't create duplicate encounters for the same date
    existing_encounter = HealthEncounter.find_by(
      health_patient: patient,
      encounter_date: date,
      encounter_type: "Shotsy Injection Tracking"
    )

    return if existing_encounter

    encounter = HealthEncounter.create(
      health_patient: patient,
      encounter_date: date,
      encounter_type: "Shotsy Injection Tracking",
      reason_for_visit: reason_parts.join("; "),
      provider_name: "Self-administered via Shotsy App",
      diagnosis: encounter_notes
    )

    if encounter.persisted?
      Rails.logger.debug "Created Shotsy injection tracking encounter for #{date}"
    else
      Rails.logger.warn "Failed to save Shotsy encounter: #{encounter.errors.full_messages.join(', ')}"
    end
  end
end
