# Health Data Seeds
# Creates sample health data for testing and demonstration

def seed_health_data(user)
  puts "🏥 Seeding health data..."

  # Create a health patient record
  patient = HealthPatient.find_or_create_by!(
    first_name: "John",
    last_name: "Doe"
  ) do |p|
    p.birth_date = "1985-06-15"
    p.gender = "Male"
    p.address = "123 Main St, Anytown, USA 12345"
    p.phone = "(555) 123-4567"
    p.email = "john.doe@example.com"
  end

  # Allergies
  allergies = [
    {
      allergen: "Penicillin",
      reaction: "Rash, itching",
      severity: "Moderate",
      status: "Active",
      onset_date: "2010-03-15"
    },
    {
      allergen: "Peanuts",
      reaction: "Anaphylaxis",
      severity: "Severe",
      status: "Active",
      onset_date: "1990-08-22"
    }
  ]

  allergies.each do |allergy|
    HealthAllergy.find_or_create_by!(
      health_patient: patient,
      allergen: allergy[:allergen]
    ) do |ha|
      ha.reaction = allergy[:reaction]
      ha.severity = allergy[:severity]
      ha.status = allergy[:status]
      ha.onset_date = allergy[:onset_date]
    end
  end

  # Medications
  medications = [
    {
      medication_name: "Lisinopril 10mg",
      dosage: "10mg",
      frequency: "Once daily",
      route: "Oral",
      start_date: "2023-01-15",
      status: "Active",
      prescriber: "Dr. Smith"
    },
    {
      medication_name: "Metformin 500mg",
      dosage: "500mg",
      frequency: "Twice daily",
      route: "Oral",
      start_date: "2022-06-01",
      status: "Active",
      prescriber: "Dr. Johnson"
    },
    {
      medication_name: "Vitamin D3",
      dosage: "1000 IU",
      frequency: "Once daily",
      route: "Oral",
      start_date: "2023-03-01",
      status: "Active",
      prescriber: "Dr. Smith"
    }
  ]

  medications.each do |med|
    HealthMedication.find_or_create_by!(
      health_patient: patient,
      medication_name: med[:medication_name],
      dosage: med[:dosage],
      start_date: med[:start_date]
    ) do |hm|
      hm.frequency = med[:frequency]
      hm.route = med[:route]
      hm.status = med[:status]
      hm.prescriber = med[:prescriber]
    end
  end

  # Health Problems
  problems = [
    {
      problem_name: "Hypertension",
      code: "I10",
      code_system: "ICD-10",
      status: "Active",
      onset_date: "2023-01-15"
    },
    {
      problem_name: "Type 2 Diabetes Mellitus",
      code: "E11.9",
      code_system: "ICD-10",
      status: "Active",
      onset_date: "2022-06-01"
    },
    {
      problem_name: "Vitamin D Deficiency",
      code: "E55.9",
      code_system: "ICD-10",
      status: "Resolved",
      onset_date: "2023-02-15",
      resolved_date: "2023-08-01"
    }
  ]

  problems.each do |problem|
    HealthProblem.find_or_create_by!(
      health_patient: patient,
      problem_name: problem[:problem_name],
      code: problem[:code],
      onset_date: problem[:onset_date]
    ) do |hp|
      hp.code_system = problem[:code_system]
      hp.status = problem[:status]
      hp.resolved_date = problem[:resolved_date]
    end
  end

  # Immunizations
  immunizations = [
    {
      vaccine_name: "COVID-19 mRNA Vaccine",
      vaccine_code: "CVX-208",
      administration_date: "2021-04-15",
      administrator: "CVS Pharmacy",
      lot_number: "EL9261",
      site: "Left deltoid",
      route: "Intramuscular"
    },
    {
      vaccine_name: "Influenza Vaccine",
      vaccine_code: "CVX-158",
      administration_date: "2023-10-01",
      administrator: "Dr. Smith",
      lot_number: "FL2023",
      site: "Right deltoid",
      route: "Intramuscular"
    },
    {
      vaccine_name: "Tetanus/Diphtheria",
      vaccine_code: "CVX-113",
      administration_date: "2020-07-22",
      administrator: "Dr. Johnson",
      lot_number: "TD2020",
      site: "Left deltoid",
      route: "Intramuscular"
    }
  ]

  immunizations.each do |immunization|
    HealthImmunization.find_or_create_by!(
      health_patient: patient,
      vaccine_name: immunization[:vaccine_name],
      administration_date: immunization[:administration_date]
    ) do |hi|
      hi.vaccine_code = immunization[:vaccine_code]
      hi.administrator = immunization[:administrator]
      hi.lot_number = immunization[:lot_number]
      hi.site = immunization[:site]
      hi.route = immunization[:route]
    end
  end

  # Vital Signs (monthly readings)
  6.times do |i|
    measurement_date = (i + 1).months.ago.strftime("%Y-%m-%d")

    HealthVitalSign.find_or_create_by!(
      health_patient: patient,
      measurement_date: measurement_date
    ) do |hvs|
      hvs.height = 70.0 # inches
      hvs.weight = 180.0 + rand(-5..5) # lbs with some variation
      hvs.bmi = (hvs.weight / (hvs.height * hvs.height) * 703).round(1)
      hvs.systolic_bp = 120 + rand(-10..20)
      hvs.diastolic_bp = 80 + rand(-5..10)
      hvs.heart_rate = 70 + rand(-10..20)
      hvs.temperature = 98.6
      hvs.respiratory_rate = 16 + rand(-2..4)
      hvs.oxygen_saturation = 98 + rand(0..2)
    end
  end

  # Medical Encounters
  encounters = [
    {
      encounter_date: "2023-08-15",
      encounter_type: "Office Visit",
      reason_for_visit: "Annual Physical Exam",
      provider_name: "Dr. Smith",
      provider_specialty: "Internal Medicine",
      facility_name: "Main Street Medical Center",
      encounter_status: "Completed",
      diagnosis: "Routine health maintenance"
    },
    {
      encounter_date: "2023-06-01",
      encounter_type: "Office Visit",
      reason_for_visit: "Follow-up for diabetes",
      provider_name: "Dr. Johnson",
      provider_specialty: "Endocrinology",
      facility_name: "Diabetes Care Center",
      encounter_status: "Completed",
      diagnosis: "Type 2 diabetes mellitus, well controlled"
    },
    {
      encounter_date: "2023-03-22",
      encounter_type: "Lab Work",
      reason_for_visit: "Quarterly lab work",
      provider_name: "Lab Tech",
      provider_specialty: "Laboratory",
      facility_name: "Quest Diagnostics",
      encounter_status: "Completed",
      diagnosis: "Laboratory studies"
    }
  ]

  encounters.each do |encounter|
    HealthEncounter.find_or_create_by!(
      health_patient: patient,
      encounter_date: encounter[:encounter_date],
      encounter_type: encounter[:encounter_type]
    ) do |he|
      he.reason_for_visit = encounter[:reason_for_visit]
      he.provider_name = encounter[:provider_name]
      he.provider_specialty = encounter[:provider_specialty]
      he.facility_name = encounter[:facility_name]
      he.encounter_status = encounter[:encounter_status]
      he.diagnosis = encounter[:diagnosis]
    end
  end

  # Sleep Data (CPAP/ResMed data)
  30.times do |i|
    session_date = (i + 1).days.ago.strftime("%Y-%m-%d")

    HealthSleepData.find_or_create_by!(
      health_patient: patient,
      session_date: session_date
    ) do |hsd|
      hsd.usage_hours = 6.5 + rand(-1.5..2.0).round(1)
      hsd.sleep_score = rand(70..95)
      hsd.ahi_score = rand(1.0..5.0).round(1)
      hsd.leak_score = rand(80..100)
      hsd.mask_score = rand(85..100)
      hsd.usage_score = hsd.usage_hours >= 4 ? rand(90..100) : rand(50..89)
      hsd.mask_session_count = 1
      hsd.ahi = hsd.ahi_score
      hsd.leak_50_percentile = rand(0..20)
      hsd.leak_70_percentile = rand(5..25)
      hsd.leak_95_percentile = rand(10..40)
      hsd.mode = "CPAP"
      hsd.device_serial = "12345678"
    end
  end

  puts "   ✅ Created 1 health patient record"
  puts "   ✅ Created #{HealthAllergy.where(health_patient: patient).count} allergies"
  puts "   ✅ Created #{HealthMedication.where(health_patient: patient).count} medications"
  puts "   ✅ Created #{HealthProblem.where(health_patient: patient).count} health problems"
  puts "   ✅ Created #{HealthImmunization.where(health_patient: patient).count} immunizations"
  puts "   ✅ Created #{HealthVitalSign.where(health_patient: patient).count} vital sign records"
  puts "   ✅ Created #{HealthEncounter.where(health_patient: patient).count} medical encounters"
  puts "   ✅ Created #{HealthSleepData.where(health_patient: patient).count} sleep data records"
end
