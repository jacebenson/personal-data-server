require "nokogiri"

class HealthImportService
  attr_reader :errors, :summary

  def initialize
    @errors = []
    @summary = {
      patients: 0,
      allergies: 0,
      medications: 0,
      problems: 0,
      immunizations: 0,
      vital_signs: 0,
      encounters: 0,
      skipped: 0
    }
  end

  def import_from_xml(xml_file_path)
    Rails.logger.info "Starting health data import from: #{xml_file_path}"

    unless File.exist?(xml_file_path)
      @errors << "XML file not found: #{xml_file_path}"
      return false
    end

    begin
      # Parse XML file
      doc = Nokogiri::XML(File.read(xml_file_path))

      # Handle namespace - HL7 CDA documents use a namespace
      doc.remove_namespaces!
      clinical_document = doc.at_xpath("//ClinicalDocument")

      unless clinical_document
        @errors << "Invalid XML format: ClinicalDocument not found"
        return false
      end

      ActiveRecord::Base.transaction do
        # Extract and create/update patient
        patient = extract_patient_info(clinical_document)
        return false unless patient

        # Process each section
        sections = clinical_document.xpath(".//component/structuredBody/component/section")
        sections.each do |section|
          process_section(section, patient)
        end
      end

      Rails.logger.info "Health data import completed successfully"
      true
    rescue => e
      @errors << "Error parsing XML: #{e.message}"
      Rails.logger.error "Health import error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  def extract_patient_info(clinical_document)
    Rails.logger.info "Extracting patient information"

    record_target = clinical_document.at_xpath(".//recordTarget/patientRole")
    patient_elem = record_target.at_xpath("./patient")

    # Extract name
    first_name = ""
    last_name = ""
    name_elem = patient_elem.at_xpath('./name[@use="L"]') || patient_elem.at_xpath("./name")
    if name_elem
      given_elems = name_elem.xpath("./given")
      first_name = given_elems.map(&:text).join(" ")
      family_elem = name_elem.at_xpath("./family")
      last_name = family_elem&.text || ""
    end

    # Extract birth date
    birth_date = ""
    birth_time = patient_elem.at_xpath("./birthTime")
    if birth_time && birth_time["value"]
      value = birth_time["value"]
      if value.length >= 8
        year = value[0..3]
        month = value[4..5]
        day = value[6..7]
        birth_date = "#{year}-#{month}-#{day}"
      end
    end

    # Extract gender
    gender = ""
    gender_code = patient_elem.at_xpath("./administrativeGenderCode")
    gender = gender_code["code"] if gender_code

    # Extract address
    address = ""
    addr_elem = record_target.at_xpath('./addr[@use="HP"]') || record_target.at_xpath("./addr")
    if addr_elem
      parts = []
      street = addr_elem.at_xpath("./streetAddressLine")
      city = addr_elem.at_xpath("./city")
      state = addr_elem.at_xpath("./state")
      postal = addr_elem.at_xpath("./postalCode")

      parts << street.text if street
      parts << city.text if city
      parts << state.text if state
      parts << postal.text if postal
      address = parts.join(", ")
    end

    # Extract phone and email
    phone = ""
    email = ""
    telecoms = record_target.xpath("./telecom")
    telecoms.each do |telecom|
      value = telecom["value"]
      next unless value

      if value.start_with?("tel:")
        phone = value.gsub("tel:", "").gsub(/[^\d\-\(\)\s\+]/, "")
      elsif value.start_with?("mailto:")
        email = value.gsub("mailto:", "")
      end
    end

    # Create or update patient (using ID 1 like the JS version)
    patient = HealthPatient.find_or_initialize_by(id: 1)
    patient.assign_attributes(
      first_name: first_name,
      last_name: last_name,
      birth_date: birth_date,
      gender: gender,
      address: address,
      phone: phone,
      email: email
    )

    if patient.save
      @summary[:patients] = 1
      Rails.logger.info "Patient info saved: #{patient.full_name}"
      patient
    else
      @errors << "Failed to save patient: #{patient.errors.full_messages.join(', ')}"
      nil
    end
  end

  def process_section(section, patient)
    title_elem = section.at_xpath("./title")
    title = title_elem&.text&.downcase || ""

    Rails.logger.info "Processing section: #{title}"

    begin
      case title
      when /allergies/
        process_allergies(section, patient)
      when /medications/
        process_medications(section, patient)
      when /problems/
        process_problems(section, patient)
      when /immunizations/
        process_immunizations(section, patient)
      when /vital signs/
        process_vital_signs(section, patient)
      when /encounters/
        process_encounters(section, patient)
      else
        Rails.logger.debug "Skipping section: #{title}"
      end
    rescue => e
      @errors << "Error processing section #{title}: #{e.message}"
      @summary[:skipped] += 1
      Rails.logger.error "Section processing error: #{e.message}"
    end
  end

  def process_allergies(section, patient)
    entries = section.xpath(".//entry")

    entries.each do |entry|
      act = entry.at_xpath(".//act")
      next unless act

      relationships = act.xpath(".//entryRelationship")
      relationships.each do |rel|
        observation = rel.at_xpath("./observation")
        next unless observation

        participant = observation.at_xpath(".//participant")
        next unless participant

        entity = participant.at_xpath(".//playingEntity")
        next unless entity

        allergen = ""
        code_elem = entity.at_xpath("./code")
        name_elem = entity.at_xpath("./name")

        if code_elem && code_elem["displayName"]
          allergen = code_elem["displayName"]
        elsif name_elem
          allergen = name_elem.text
        end

        next if allergen.blank?

        allergy = patient.health_allergies.find_or_initialize_by(allergen: allergen)
        allergy.status = "active"

        if allergy.save
          @summary[:allergies] += 1 if allergy.previously_new_record?
          Rails.logger.debug "Saved allergy: #{allergen}"
        else
          Rails.logger.warn "Failed to save allergy: #{allergy.errors.full_messages.join(', ')}"
        end
      end
    end
  end

  def process_medications(section, patient)
    entries = section.xpath(".//entry")

    entries.each do |entry|
      substance_admin = entry.at_xpath("./substanceAdministration")
      next unless substance_admin

      medication_name = ""
      consumable = substance_admin.at_xpath(".//consumable/manufacturedProduct/manufacturedMaterial/code")
      if consumable && consumable["displayName"]
        medication_name = consumable["displayName"]
      end

      next if medication_name.blank?

      dosage = ""
      dose_quantity = substance_admin.at_xpath("./doseQuantity")
      if dose_quantity && dose_quantity["value"]
        unit = dose_quantity["unit"] || ""
        dosage = "#{dose_quantity['value']} #{unit}".strip
      end

      status = "active"
      status_code = substance_admin.at_xpath("./statusCode")
      status = status_code["code"] if status_code && status_code["code"]

      start_date = ""
      effective_time = substance_admin.at_xpath("./effectiveTime/low")
      if effective_time && effective_time["value"]
        start_date = format_date(effective_time["value"])
      end

      route = ""
      route_code = substance_admin.at_xpath("./routeCode")
      route = route_code["displayName"] if route_code && route_code["displayName"]

      medication = patient.health_medications.find_or_initialize_by(
        medication_name: medication_name,
        dosage: dosage,
        start_date: start_date
      )

      medication.assign_attributes(
        status: status,
        route: route
      )

      if medication.save
        @summary[:medications] += 1 if medication.previously_new_record?
        Rails.logger.debug "Saved medication: #{medication_name}"
      else
        Rails.logger.warn "Failed to save medication: #{medication.errors.full_messages.join(', ')}"
      end
    end

    # Also try to extract from text section if no structured entries
    if @summary[:medications] == 0
      process_medications_from_text(section, patient)
    end
  end

  def process_medications_from_text(section, patient)
    text_section = section.at_xpath("./text")
    return unless text_section

    list = text_section.at_xpath(".//list")
    return unless list

    items = list.xpath("./item")
    items.each do |item|
      content_elems = item.xpath('./content[@styleCode="Bold"]')
      next if content_elems.empty?

      medication_name = content_elems.first.text.strip
      next if medication_name.blank?

      # Extract start date from text
      start_date = ""
      started_match = item.text.match(/Started (\d+\/\d+\/\d+)/)
      start_date = started_match[1] if started_match

      # Extract dosage from paragraph
      dosage = ""
      paragraph = item.at_xpath('./paragraph[@styleCode="xIndent"]')
      dosage = paragraph.text.strip if paragraph

      medication = patient.health_medications.find_or_initialize_by(
        medication_name: medication_name,
        dosage: dosage,
        start_date: start_date
      )

      medication.status = "active"

      if medication.save
        @summary[:medications] += 1 if medication.previously_new_record?
        Rails.logger.debug "Saved medication from text: #{medication_name}"
      else
        Rails.logger.warn "Failed to save medication from text: #{medication.errors.full_messages.join(', ')}"
      end
    end
  end

  def process_problems(section, patient)
    entries = section.xpath(".//entry")

    entries.each do |entry|
      act = entry.at_xpath(".//act")
      next unless act

      relationships = act.xpath(".//entryRelationship")
      relationships.each do |rel|
        observation = rel.at_xpath("./observation")
        next unless observation

        value = observation.at_xpath("./value")
        next unless value

        problem_name = value["displayName"] || ""
        code = value["code"] || ""
        code_system = value["codeSystem"] || ""

        next if problem_name.blank?

        problem = patient.health_problems.find_or_initialize_by(
          problem_name: problem_name,
          code: code,
          onset_date: nil
        )

        problem.assign_attributes(
          code_system: code_system,
          status: "active"
        )

        if problem.save
          @summary[:problems] += 1 if problem.previously_new_record?
          Rails.logger.debug "Saved problem: #{problem_name}"
        else
          Rails.logger.warn "Failed to save problem: #{problem.errors.full_messages.join(', ')}"
        end
      end
    end

    # Also try to extract from table format
    process_problems_from_table(section, patient)
  end

  def process_problems_from_table(section, patient)
    table = section.at_xpath(".//table/tbody")
    return unless table

    rows = table.xpath("./tr")
    rows.each do |row|
      tds = row.xpath("./td")
      next if tds.length < 2

      problem_name = tds[0].text.strip
      onset_date = tds[1].text.strip

      next if problem_name.blank?

      problem = patient.health_problems.find_or_initialize_by(
        problem_name: problem_name,
        code: "",
        onset_date: onset_date.present? ? onset_date : nil
      )

      problem.status = "active"

      if problem.save
        @summary[:problems] += 1 if problem.previously_new_record?
        Rails.logger.debug "Saved problem from table: #{problem_name}"
      else
        Rails.logger.warn "Failed to save problem from table: #{problem.errors.full_messages.join(', ')}"
      end
    end
  end

  def process_immunizations(section, patient)
    entries = section.xpath(".//entry")

    entries.each do |entry|
      substance_admin = entry.at_xpath("./substanceAdministration")
      next unless substance_admin

      vaccine_name = ""
      vaccine_code = ""

      code = substance_admin.at_xpath(".//consumable/manufacturedProduct/manufacturedMaterial/code")
      if code
        vaccine_name = code["displayName"] || ""
        vaccine_code = code["code"] || ""
      end

      next if vaccine_name.blank?

      admin_date = ""
      effective_time = substance_admin.at_xpath("./effectiveTime")
      if effective_time && effective_time["value"]
        admin_date = format_date(effective_time["value"])
      end

      # Check if immunization already exists
      existing = HealthImmunization.find_by(
        health_patient: patient,
        vaccine_name: vaccine_name,
        vaccine_code: vaccine_code,
        administration_date: admin_date
      )

      if existing
        @summary[:skipped] += 1
        Rails.logger.debug "Skipped duplicate immunization: #{vaccine_name}"
      else
        immunization = HealthImmunization.create(
          health_patient: patient,
          vaccine_name: vaccine_name,
          vaccine_code: vaccine_code,
          administration_date: admin_date
        )

        if immunization.persisted?
          @summary[:immunizations] += 1
          Rails.logger.debug "Saved new immunization: #{vaccine_name}"
        else
          Rails.logger.warn "Failed to save immunization: #{immunization.errors.full_messages.join(', ')}"
        end
      end
    end

    # Also try to extract from text section
    process_immunizations_from_text(section, patient)
  end

  def process_immunizations_from_text(section, patient)
    text_section = section.at_xpath("./text")
    return unless text_section

    # Try list format
    list = text_section.at_xpath(".//list")
    if list
      items = list.xpath('./item[starts-with(@ID, "immunization")]')
      items.each do |item|
        content_elems = item.xpath('./content[@styleCode="Bold"]')
        next if content_elems.empty?

        vaccine_name = content_elems.first.text.strip
        next if vaccine_name.blank?

        # Extract administration dates
        admin_dates = ""
        content_elems.each do |content|
          if content.text.include?("Given")
            admin_dates = content.text
            break
          end
        end

        # Check if immunization already exists
        existing = HealthImmunization.find_by(
          health_patient: patient,
          vaccine_name: vaccine_name,
          vaccine_code: item["ID"] || "",
          administration_date: admin_dates
        )

        if existing
          @summary[:skipped] += 1
          Rails.logger.debug "Skipped duplicate immunization from text: #{vaccine_name}"
        else
          immunization = HealthImmunization.create(
            health_patient: patient,
            vaccine_name: vaccine_name,
            vaccine_code: item["ID"] || "",
            administration_date: admin_dates
          )

          if immunization.persisted?
            @summary[:immunizations] += 1
            Rails.logger.debug "Saved immunization from text: #{vaccine_name}"
          end
        end
      end
    end

    # Try table format
    table = text_section.at_xpath(".//table/tbody")
    return unless table

    rows = table.xpath("./tr")
    rows.each do |row|
      tds = row.xpath("./td")
      next if tds.length < 2

      vaccine_name = tds[0].text.strip
      admin_date = tds[1].text.strip

      next if vaccine_name.blank?

      # Check if immunization already exists
      existing = HealthImmunization.find_by(
        health_patient: patient,
        vaccine_name: vaccine_name,
        vaccine_code: "",
        administration_date: admin_date
      )

      if existing
        @summary[:skipped] += 1
        Rails.logger.debug "Skipped duplicate immunization from table: #{vaccine_name}"
      else
        immunization = HealthImmunization.create(
          health_patient: patient,
          vaccine_name: vaccine_name,
          vaccine_code: "",
          administration_date: admin_date
        )

        if immunization.persisted?
          @summary[:immunizations] += 1
          Rails.logger.debug "Saved immunization from table: #{vaccine_name}"
        end
      end
    end
  end

  def process_vital_signs(section, patient)
    entries = section.xpath(".//entry")

    entries.each do |entry|
      organizer = entry.at_xpath("./organizer")
      next unless organizer

      measurement_date = ""
      effective_time = organizer.at_xpath("./effectiveTime")
      if effective_time && effective_time["value"]
        measurement_date = format_date(effective_time["value"])
      end

      vitals = {}
      components = organizer.xpath("./component")

      components.each do |component|
        observation = component.at_xpath("./observation")
        next unless observation

        code_elem = observation.at_xpath("./code")
        value_elem = observation.at_xpath("./value")
        next unless code_elem && value_elem

        code = code_elem["code"]
        value = value_elem["value"].to_f

        case code
        when "8302-2" # Height
          vitals[:height] = value
        when "29463-7" # Weight
          vitals[:weight] = value
        when "39156-5" # BMI
          vitals[:bmi] = value
        when "8480-6" # Systolic BP
          vitals[:systolic_bp] = value.to_i
        when "8462-4" # Diastolic BP
          vitals[:diastolic_bp] = value.to_i
        when "8867-4" # Heart rate
          vitals[:heart_rate] = value.to_i
        when "8310-5" # Temperature
          vitals[:temperature] = value
        when "9279-1" # Respiratory rate
          vitals[:respiratory_rate] = value.to_i
        when "2708-6" # Oxygen saturation
          vitals[:oxygen_saturation] = value
        end
      end

      if vitals.any?
        # Check if vital signs already exist for this date and patient with the same data
        existing = HealthVitalSign.find_by(
          health_patient: patient,
          measurement_date: measurement_date,
          height: vitals[:height],
          weight: vitals[:weight],
          bmi: vitals[:bmi],
          systolic_bp: vitals[:systolic_bp],
          diastolic_bp: vitals[:diastolic_bp],
          heart_rate: vitals[:heart_rate],
          temperature: vitals[:temperature],
          respiratory_rate: vitals[:respiratory_rate],
          oxygen_saturation: vitals[:oxygen_saturation]
        )

        if existing
          @summary[:skipped] += 1
          Rails.logger.debug "Skipped duplicate vital signs for #{measurement_date}"
        else
          vital_sign = HealthVitalSign.create(
            health_patient: patient,
            measurement_date: measurement_date,
            **vitals
          )

          if vital_sign.persisted?
            @summary[:vital_signs] += 1
            Rails.logger.debug "Saved vital signs for #{measurement_date}"
          else
            Rails.logger.warn "Failed to save vital signs: #{vital_sign.errors.full_messages.join(', ')}"
          end
        end
      end
    end
  end

  def process_encounters(section, patient)
    entries = section.xpath(".//entry")

    entries.each do |entry|
      encounter = entry.at_xpath("./encounter")
      next unless encounter

      encounter_date = ""
      effective_time = encounter.at_xpath("./effectiveTime/low")
      if effective_time && effective_time["value"]
        encounter_date = format_date(effective_time["value"])
      end

      encounter_type = ""
      code = encounter.at_xpath("./code")
      encounter_type = code["displayName"] if code && code["displayName"]

      provider_name = ""
      provider_specialty = ""
      performer = encounter.at_xpath("./performer/assignedEntity")
      if performer
        person = performer.at_xpath("./assignedPerson/name")
        if person
          parts = []
          prefix = person.at_xpath("./prefix")
          given = person.at_xpath("./given")
          family = person.at_xpath("./family")

          parts << prefix.text if prefix
          parts << given.text if given
          parts << family.text if family
          provider_name = parts.join(" ")
        end

        specialty_code = performer.at_xpath("./code")
        provider_specialty = specialty_code["displayName"] if specialty_code && specialty_code["displayName"]
      end

      facility_name = ""
      participant = encounter.at_xpath("./participant/participantRole/playingEntity")
      if participant
        name_elem = participant.at_xpath("./name")
        facility_name = name_elem.text if name_elem
      end

      if encounter_date.present? || encounter_type.present? || provider_name.present?
        # Check if encounter already exists
        existing = HealthEncounter.find_by(
          health_patient: patient,
          encounter_date: encounter_date,
          provider_name: provider_name
        )

        if existing
          @summary[:skipped] += 1
          Rails.logger.debug "Skipped duplicate encounter: #{encounter_type} on #{encounter_date} with #{provider_name}"
        else
          encounter_record = HealthEncounter.create(
            health_patient: patient,
            encounter_date: encounter_date,
            encounter_type: encounter_type,
            provider_name: provider_name,
            provider_specialty: provider_specialty,
            facility_name: facility_name,
            encounter_status: "completed"
          )

          if encounter_record.persisted?
            @summary[:encounters] += 1
            Rails.logger.debug "Saved encounter: #{encounter_type} on #{encounter_date}"
          else
            Rails.logger.warn "Failed to save encounter: #{encounter_record.errors.full_messages.join(', ')}"
          end
        end
      end
    end
  end

  def format_date(date_value)
    return "" unless date_value && date_value.length >= 8

    year = date_value[0..3]
    month = date_value[4..5]
    day = date_value[6..7]
    "#{year}-#{month}-#{day}"
  end
end
