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
      total_encounters: @patient.health_encounters.count
    }

    # Get all data for comprehensive view
    @allergies = @patient.health_allergies.order(:allergen)
    @medications = @patient.health_medications.order(:medication_name)
    @problems = @patient.health_problems.order(:problem_name)
    @immunizations = @patient.health_immunizations.order(:administration_date)
    @vital_signs = @patient.health_vital_signs.order(:measurement_date)
    @encounters = @patient.health_encounters.order(:encounter_date)

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
      }
    }

    render "view_all"
  end

  def import
    # Show import form
  end

  def process_import
    if params[:xml_file].blank?
      redirect_to import_health_index_path, alert: "Please select an XML file to import"
      return
    end

    uploaded_file = params[:xml_file]

    # Create temp directory if it doesn't exist
    temp_dir = Rails.root.join("tmp", "health_uploads")
    FileUtils.mkdir_p(temp_dir)

    # Save uploaded file
    temp_file_path = temp_dir.join("#{Time.current.to_i}_#{uploaded_file.original_filename}")
    File.open(temp_file_path, "wb") do |file|
      file.write(uploaded_file.read)
    end

    begin
      # Process the import
      import_service = HealthImportService.new
      success = import_service.import_from_xml(temp_file_path.to_s)

      if success
        redirect_to health_index_path, notice: build_success_message(import_service.summary)
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
    @current_medications = @patient.health_medications.current.includes(:health_patient)
    @historical_medications = @patient.health_medications.historical.includes(:health_patient)
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

  private

  def build_success_message(summary)
    parts = []
    parts << "#{summary[:patients]} patient record updated" if summary[:patients] > 0
    parts << "#{summary[:allergies]} allergies" if summary[:allergies] > 0
    parts << "#{summary[:medications]} medications" if summary[:medications] > 0
    parts << "#{summary[:problems]} problems" if summary[:problems] > 0
    parts << "#{summary[:immunizations]} immunizations" if summary[:immunizations] > 0
    parts << "#{summary[:vital_signs]} vital sign records" if summary[:vital_signs] > 0
    parts << "#{summary[:encounters]} encounters" if summary[:encounters] > 0

    if parts.any?
      "Successfully imported: #{parts.join(', ')}"
    else
      "Import completed, but no new records were added"
    end
  end
end
