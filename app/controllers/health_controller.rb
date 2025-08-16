class HealthController < ApplicationController
  def index
    # Comprehensive health data view (formerly view_all)
    @patient = HealthPatient.first # For now, show first patient

    unless @patient
      # Show empty state for no health data
      @patients = []
      @total_records = {
        allergies: 0,
        medications: 0,
        problems: 0,
        immunizations: 0,
        vital_signs: 0,
        encounters: 0
      }
      render "empty_state"
      return
    end

    # Summary statistics
    @summary_stats = {
      total_allergies: @patient.health_allergies.count,
      active_allergies: @patient.health_allergies.where(status: "active").count,
      total_medications: @patient.health_medications.count,
      active_medications: @patient.health_medications.where(status: "active").count,
      total_problems: @patient.health_problems.count,
      active_problems: @patient.health_problems.where(status: "active").count,
      total_immunizations: @patient.health_immunizations.count,
      total_vital_signs: @patient.health_vital_signs.count,
      total_encounters: @patient.health_encounters.count,
      total_sleep_sessions: @patient.health_sleep_data.count
    }

    # Get all data for comprehensive view with better sorting
    @allergies = @patient.health_allergies.order(:allergen)
    @medications = @patient.health_medications
                          .order(Arel.sql("
                            CASE status
                              WHEN 'active' THEN 1
                              WHEN 'completed' THEN 2
                              WHEN 'missed' THEN 3
                              ELSE 4
                            END,
                            start_date DESC
                          "))
    @problems = @patient.health_problems.order(:problem_name)
    @immunizations = @patient.health_immunizations.order(:administration_date)
    @vital_signs = @patient.health_vital_signs.order(:measurement_date)
    @encounters = @patient.health_encounters.order(:encounter_date)
    @sleep_data = @patient.health_sleep_data.order(session_date: :desc)

    # Date ranges
    @date_ranges = {
      medications: {
        earliest: @patient.health_medications.where.not(start_date: [ nil, "" ]).minimum(:start_date),
        latest: @patient.health_medications.where.not(start_date: [ nil, "" ]).maximum(:start_date)
      },
      problems: {
        earliest: @patient.health_problems.where.not(onset_date: [ nil, "" ]).minimum(:onset_date),
        latest: @patient.health_problems.where.not(onset_date: [ nil, "" ]).maximum(:onset_date)
      },
      vital_signs: {
        earliest: @patient.health_vital_signs.where.not(measurement_date: [ nil, "" ]).minimum(:measurement_date),
        latest: @patient.health_vital_signs.where.not(measurement_date: [ nil, "" ]).maximum(:measurement_date)
      },
      sleep_data: {
        earliest: @patient.health_sleep_data.where.not(session_date: [ nil, "" ]).minimum(:session_date),
        latest: @patient.health_sleep_data.where.not(session_date: [ nil, "" ]).maximum(:session_date)
      }
    }

    render "view_all"
  end

  def import
    # Show import form
  end

  def process_import
    # Check if we have an XML file or CSV file
    if params[:xml_file].blank? && params[:csv_file].blank?
      redirect_to import_health_index_path, alert: "Please select a file to import (XML or CSV)"
      return
    end

    uploaded_file = params[:xml_file] || params[:csv_file]
    file_type = uploaded_file.original_filename.downcase.end_with?('.csv') ? :csv : :xml

    # Create temp directory if it doesn't exist
    temp_dir = Rails.root.join("tmp", "health_uploads")
    FileUtils.mkdir_p(temp_dir)

    # Save uploaded file
    temp_file_path = temp_dir.join("#{Time.current.to_i}_#{uploaded_file.original_filename}")
    File.open(temp_file_path, "wb") do |file|
      file.write(uploaded_file.read)
    end

    begin
      # Process the import based on file type and content
      if file_type == :csv
        # Determine CSV type by filename or content
        filename = uploaded_file.original_filename.downcase
        
        if filename.include?('sleep_record') || filename.include?('resmed') || filename.include?('cpap')
          # Process ResMed CPAP CSV import
          import_service = ResmedCpapImportService.new
          success = import_service.import_from_csv(temp_file_path.to_s)
        else
          # Process Shotsy CSV import
          import_service = ShotsyImportService.new
          success = import_service.import_from_csv(temp_file_path.to_s)
        end
      else
        # Process XML import (existing functionality)
        import_service = HealthImportService.new
        success = import_service.import_from_xml(temp_file_path.to_s)
      end

      if success
        redirect_to health_index_path, notice: build_success_message(import_service.summary, file_type, import_service.class.name)
      else
        redirect_to import_health_index_path, alert: "Import failed: #{import_service.errors.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Health import error: #{e.message}"
      redirect_to import_health_index_path, alert: "Import failed: #{e.message}"
    ensure
      # Clean up temp file
      File.delete(temp_file_path) if File.exist?(temp_file_path)
    end
  end

  def allergies
    @patient = HealthPatient.find(params[:id])
    @allergies = @patient.health_allergies.includes(:health_patient)
  end

  def medications
    @patient = HealthPatient.find(params[:id])
    
    # Get all medications and sort them properly
    all_medications = @patient.health_medications.includes(:health_patient)
    
    # Separate active medications from completed/missed injections
    @active_medications = all_medications.where(status: 'active')
                                        .order(:medication_name)
    
    # Get Shotsy injections (completed and missed) sorted by date descending
    @shotsy_injections = all_medications.where(status: ['completed', 'missed'])
                                       .order('start_date DESC')
    
    # Get other historical medications (not Shotsy injections)
    @historical_medications = all_medications.where.not(status: ['active', 'completed', 'missed'])
                                           .or(all_medications.where(status: 'active', end_date: ...Date.current))
                                           .order('start_date DESC')
  end

  def problems
    @patient = HealthPatient.find(params[:id])
    @active_problems = @patient.health_problems.active.includes(:health_patient)
    @resolved_problems = @patient.health_problems.resolved.includes(:health_patient)
  end

  def immunizations
    @patient = HealthPatient.find(params[:id])
    @immunizations = @patient.health_immunizations.includes(:health_patient).order(administration_date: :desc)
  end

  def vital_signs
    @patient = HealthPatient.find(params[:id])
    @vital_signs = @patient.health_vital_signs.includes(:health_patient).order(measurement_date: :desc)
  end

  def encounters
    @patient = HealthPatient.find(params[:id])
    @encounters = @patient.health_encounters.includes(:health_patient).order(encounter_date: :desc)
  end

  def sleep_data
    @patient = HealthPatient.find(params[:id])
    @sleep_sessions = @patient.health_sleep_data.includes(:health_patient).order(session_date: :desc)
  end

  private

  def build_success_message(summary, file_type = :xml, service_class = nil)
    parts = []
    parts << "#{summary[:patients]} patient record updated" if summary[:patients] && summary[:patients] > 0
    parts << "#{summary[:allergies]} allergies" if summary[:allergies] && summary[:allergies] > 0
    parts << "#{summary[:medications]} medications" if summary[:medications] && summary[:medications] > 0
    parts << "#{summary[:problems]} problems" if summary[:problems] && summary[:problems] > 0
    parts << "#{summary[:immunizations]} immunizations" if summary[:immunizations] && summary[:immunizations] > 0
    parts << "#{summary[:vital_signs]} vital sign records" if summary[:vital_signs] && summary[:vital_signs] > 0
    parts << "#{summary[:encounters]} encounters" if summary[:encounters] && summary[:encounters] > 0
    parts << "#{summary[:sleep_sessions]} sleep sessions" if summary[:sleep_sessions] && summary[:sleep_sessions] > 0

    # Determine source based on service class
    source = case service_class
             when 'ResmedCpapImportService'
               "ResMed CPAP CSV"
             when 'ShotsyImportService'
               "Shotsy CSV"
             else
               file_type == :csv ? "CSV" : "Health XML"
             end
    
    if parts.any?
      "Successfully imported from #{source}: #{parts.join(', ')}"
    else
      "#{source} import completed, but no new records were added"
    end
  end
end
