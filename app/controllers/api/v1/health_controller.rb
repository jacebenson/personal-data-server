class Api::V1::HealthController < Api::V1::BaseController
  def index
    patient = HealthPatient.first
    return render_error('No health data available', :not_found) unless patient
    
    search_query = params[:q]&.downcase
    limit = (params[:limit] || 50).to_i
    
    render_success({
      patient: {
        name: patient.full_name,
        age: patient.age,
        gender: patient.gender
      },
      allergies: search_allergies(patient, search_query).limit(limit),
      medications: search_medications(patient, search_query).limit(limit),
      problems: search_problems(patient, search_query).limit(limit),
      immunizations: search_immunizations(patient, search_query).limit(limit),
      vital_signs: search_vital_signs(patient, search_query).limit(limit),
      encounters: search_encounters(patient, search_query).limit(limit)
    })
  end

  private

  def search_allergies(patient, query)
    allergies = patient.health_allergies.order(allergen: :desc)
    allergies = allergies.where("LOWER(allergen) LIKE ? OR LOWER(reaction) LIKE ?", "%#{query}%", "%#{query}%") if query.present?
    
    allergies.map do |allergy|
      {
        allergen: allergy.allergen,
        reaction: allergy.reaction,
        severity: allergy.severity,
        status: allergy.status,
        onset_date: allergy.onset_date
      }
    end
  end

  def search_medications(patient, query)
    medications = patient.health_medications.order(medication_name: :desc)
    medications = medications.where("LOWER(medication_name) LIKE ?", "%#{query}%") if query.present?
    
    medications.map do |med|
      {
        name: med.medication_name,
        dosage: med.dosage,
        frequency: med.frequency,
        route: med.route,
        status: med.status,
        start_date: med.start_date,
        prescriber: med.prescriber
      }
    end
  end

  def search_problems(patient, query)
    problems = patient.health_problems.order(problem_name: :desc)
    problems = problems.where("LOWER(problem_name) LIKE ?", "%#{query}%") if query.present?
    
    problems.map do |problem|
      {
        name: problem.problem_name,
        code: problem.problem_code,
        status: problem.status,
        severity: problem.severity,
        onset_date: problem.onset_date,
        resolution_date: problem.resolution_date
      }
    end
  end

  def search_immunizations(patient, query)
    immunizations = patient.health_immunizations.order(administration_date: :desc)
    immunizations = immunizations.where("LOWER(vaccine_name) LIKE ?", "%#{query}%") if query.present?
    
    immunizations.map do |imm|
      {
        vaccine_name: imm.vaccine_name,
        administration_date: imm.administration_date,
        administered_by: imm.administered_by,
        lot_number: imm.lot_number
      }
    end
  end

  def search_vital_signs(patient, query)
    vital_signs = patient.health_vital_signs.order(measurement_date: :desc)
    # No text search for vital signs since they're mostly numeric
    
    vital_signs.map do |vs|
      {
        measurement_date: vs.measurement_date,
        height: vs.height,
        weight: vs.weight,
        bmi: vs.bmi,
        systolic_bp: vs.systolic_bp,
        diastolic_bp: vs.diastolic_bp,
        heart_rate: vs.heart_rate,
        temperature: vs.temperature
      }
    end
  end

  def search_encounters(patient, query)
    encounters = patient.health_encounters.order(encounter_date: :desc)
    encounters = encounters.where("LOWER(encounter_type) LIKE ? OR LOWER(provider_name) LIKE ? OR LOWER(facility_name) LIKE ?", "%#{query}%", "%#{query}%", "%#{query}%") if query.present?
    
    encounters.map do |enc|
      {
        date: enc.encounter_date,
        type: enc.encounter_type,
        provider_name: enc.provider_name,
        facility_name: enc.facility_name,
        status: enc.encounter_status
      }
    end
  end
end
