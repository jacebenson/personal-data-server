namespace :health do
  desc "Import health data from XML file"
  task :import, [:xml_file_path] => :environment do |task, args|
    xml_file_path = args[:xml_file_path]

    if xml_file_path.blank?
      puts "Usage: rails health:import[/path/to/health_document.xml]"
      puts "Example: rails health:import[tmp/DOC0001.XML]"
      exit 1
    end

    # Resolve relative paths
    xml_file_path = Rails.root.join(xml_file_path) unless Pathname.new(xml_file_path).absolute?

    puts "🔄 Importing health data from: #{xml_file_path}"

    unless File.exist?(xml_file_path)
      puts "❌ Error: File not found at #{xml_file_path}"
      exit 1
    end

    import_service = HealthImportService.new
    success = import_service.import_from_xml(xml_file_path.to_s)

    if success
      puts "✅ Health data import completed successfully!"
      puts ""
      puts "📊 Import Summary:"
      import_service.summary.each do |key, count|
        next if count == 0
        puts "   - #{key.to_s.humanize}: #{count}"
      end

      puts ""
      puts "📋 Database Totals:"
      puts "   - Patients: #{HealthPatient.count}"
      puts "   - Allergies: #{HealthAllergy.count}"
      puts "   - Medications: #{HealthMedication.count}"
      puts "   - Problems: #{HealthProblem.count}"
      puts "   - Immunizations: #{HealthImmunization.count}"
      puts "   - Vital Signs: #{HealthVitalSign.count}"
      puts "   - Encounters: #{HealthEncounter.count}"

      if HealthPatient.any?
        patient = HealthPatient.first
        puts ""
        puts "👤 Patient: #{patient.full_name}"
        puts "   View at: http://localhost:3000/health/#{patient.id}"
      end
    else
      puts "❌ Health data import failed!"
      puts ""
      puts "🚨 Errors:"
      import_service.errors.each do |error|
        puts "   - #{error}"
      end
      exit 1
    end
  end

  desc "Clear all health data"
  task clear: :environment do
    print "⚠️  This will delete ALL health data. Are you sure? (y/N): "
    response = STDIN.gets.chomp.downcase

    if response == 'y' || response == 'yes'
      puts "🗑️  Clearing all health data..."

      HealthEncounter.destroy_all
      HealthVitalSign.destroy_all
      HealthImmunization.destroy_all
      HealthProblem.destroy_all
      HealthMedication.destroy_all
      HealthAllergy.destroy_all
      HealthPatient.destroy_all

      puts "✅ All health data cleared!"
    else
      puts "❌ Operation cancelled."
    end
  end

  desc "Show health data summary"
  task summary: :environment do
    puts "📋 Health Data Summary"
    puts "=" * 30
    puts "Patients: #{HealthPatient.count}"
    puts "Allergies: #{HealthAllergy.count}"
    puts "Medications: #{HealthMedication.count}"
    puts "Problems: #{HealthProblem.count}"
    puts "Immunizations: #{HealthImmunization.count}"
    puts "Vital Signs: #{HealthVitalSign.count}"
    puts "Encounters: #{HealthEncounter.count}"

    if HealthPatient.any?
      puts ""
      HealthPatient.all.each do |patient|
        puts "👤 #{patient.full_name}"
        puts "   Born: #{patient.formatted_birth_date}" if patient.birth_date.present?
        puts "   Age: #{patient.age}" if patient.age
        puts "   Email: #{patient.email}" if patient.email.present?
        puts "   Phone: #{patient.phone}" if patient.phone.present?
        puts ""
      end
    else
      puts ""
      puts "No health data found. Import some health records to get started."
      puts "Usage: rails health:import[tmp/DOC0001.XML]"
    end
  end
end
