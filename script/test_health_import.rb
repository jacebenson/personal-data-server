#!/usr/bin/env ruby

# Test script for health data import
# Usage: ruby test_health_import.rb /path/to/DOC0001.XML

require_relative '../config/environment'

xml_file_path = ARGV[0] || '/home/jace/git/personal-data-server/tmp/DOC0001.XML'

unless File.exist?(xml_file_path)
  puts "Error: XML file not found at #{xml_file_path}"
  puts "Usage: ruby test_health_import.rb /path/to/health_document.xml"
  exit 1
end

puts "🔄 Starting health data import from: #{xml_file_path}"
puts "=" * 60

# Clear existing data for fresh import
puts "Clearing existing health data..."
HealthEncounter.destroy_all
HealthVitalSign.destroy_all
HealthImmunization.destroy_all
HealthProblem.destroy_all
HealthMedication.destroy_all
HealthAllergy.destroy_all
HealthPatient.destroy_all

# Initialize import service
import_service = HealthImportService.new

# Measure import time
start_time = Time.current
success = import_service.import_from_xml(xml_file_path)
end_time = Time.current

puts "\n" + "=" * 60

if success
  puts "✅ Health data import completed successfully!"
  puts "📊 Import Summary:"
  puts "   - Time taken: #{(end_time - start_time).round(2)} seconds"

  summary = import_service.summary
  summary.each do |key, count|
    next if count == 0
    puts "   - #{key.to_s.humanize}: #{count}"
  end

  puts "\n📋 Database Contents:"
  puts "   - Patients: #{HealthPatient.count}"
  puts "   - Allergies: #{HealthAllergy.count}"
  puts "   - Medications: #{HealthMedication.count}"
  puts "   - Problems: #{HealthProblem.count}"
  puts "   - Immunizations: #{HealthImmunization.count}"
  puts "   - Vital Signs: #{HealthVitalSign.count}"
  puts "   - Encounters: #{HealthEncounter.count}"

  # Show patient info
  if HealthPatient.any?
    patient = HealthPatient.first
    puts "\n👤 Patient Information:"
    puts "   - Name: #{patient.full_name}"
    puts "   - Birth Date: #{patient.formatted_birth_date}"
    puts "   - Age: #{patient.age} years old" if patient.age
    puts "   - Gender: #{patient.gender}"
    puts "   - Phone: #{patient.phone}" if patient.phone.present?
    puts "   - Email: #{patient.email}" if patient.email.present?
  end

  # Show sample data
  if HealthAllergy.any?
    puts "\n🚫 Sample Allergies:"
    HealthAllergy.limit(3).each do |allergy|
      puts "   - #{allergy.display_name}"
    end
  end

  if HealthMedication.current.any?
    puts "\n💊 Current Medications:"
    HealthMedication.current.limit(3).each do |med|
      puts "   - #{med.display_name}"
    end
  end

  if HealthProblem.active.any?
    puts "\n🏥 Active Problems:"
    HealthProblem.active.limit(3).each do |problem|
      puts "   - #{problem.display_name}"
    end
  end

else
  puts "❌ Health data import failed!"
  puts "\n🚨 Errors encountered:"
  import_service.errors.each do |error|
    puts "   - #{error}"
  end
end

puts "\n" + "=" * 60
puts "Import process completed."
