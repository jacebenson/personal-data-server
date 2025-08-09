class HealthController < ApplicationController
  before_action :set_patient, only: [:show, :import]

  def index
    @patients = HealthPatient.all
    @total_records = {
      allergies: HealthAllergy.count,
      medications: HealthMedication.count,
      problems: HealthProblem.count,
      immunizations: HealthImmunization.count,
      vital_signs: HealthVitalSign.count,
      encounters: HealthEncounter.count
    }
  end

  def show
    @allergies = @patient.health_allergies.active
    @current_medications = @patient.health_medications.current
    @active_problems = @patient.health_problems.active
    @recent_immunizations = @patient.health_immunizations.recent
    @recent_vitals = @patient.health_vital_signs.recent.order(measurement_date: :desc).limit(5)
    @recent_encounters = @patient.health_encounters.recent.order(encounter_date: :desc).limit(10)
  end

  def import
    # Show import form
  end

  def process_import
    if params[:xml_file].blank?
      redirect_to import_health_index_path, alert: 'Please select an XML file to import'
      return
    end

    uploaded_file = params[:xml_file]

    # Create temp directory if it doesn't exist
    temp_dir = Rails.root.join('tmp', 'health_uploads')
    FileUtils.mkdir_p(temp_dir)

    # Save uploaded file
    temp_file_path = temp_dir.join("#{Time.current.to_i}_#{uploaded_file.original_filename}")
    File.open(temp_file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end

    begin
      # Process the import
      import_service = HealthImportService.new
      success = import_service.import_from_xml(temp_file_path.to_s)

      if success
        redirect_to health_path(1), notice: build_success_message(import_service.summary)
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

  def set_patient
    @patient = HealthPatient.find_by(id: params[:id]) || HealthPatient.find_by(id: 1)

    unless @patient
      redirect_to health_index_path, alert: 'No health data found. Please import health records first.'
    end
  end

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
