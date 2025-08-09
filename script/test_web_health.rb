#!/usr/bin/env ruby

# Quick test to verify the health import works via the web interface
# This script will simulate uploading the XML file

require_relative '../config/environment'

puts "🔄 Testing Health Import Web Interface"
puts "=" * 50

# Check if the XML file exists
xml_file_path = Rails.root.join('tmp', 'DOC0001.XML')

unless File.exist?(xml_file_path)
  puts "❌ XML file not found at #{xml_file_path}"
  puts "Please make sure the DOC0001.XML file is in the tmp/ directory"
  exit 1
end

puts "✅ XML file found at #{xml_file_path}"
puts "📄 File size: #{File.size(xml_file_path)} bytes"

# Test the import service directly
puts "\n🧪 Testing HealthImportService..."

import_service = HealthImportService.new
success = import_service.import_from_xml(xml_file_path.to_s)

if success
  puts "✅ Import service working correctly!"
  puts "📊 Summary: #{import_service.summary}"

  # Show current database state
  puts "\n📋 Current Database State:"
  puts "   - Patients: #{HealthPatient.count}"
  puts "   - Allergies: #{HealthAllergy.count}"
  puts "   - Medications: #{HealthMedication.count}"
  puts "   - Problems: #{HealthProblem.count}"
  puts "   - Immunizations: #{HealthImmunization.count}"
  puts "   - Vital Signs: #{HealthVitalSign.count}"
  puts "   - Encounters: #{HealthEncounter.count}"

  if HealthPatient.any?
    patient = HealthPatient.first
    puts "\n👤 Patient: #{patient.full_name}"
    puts "   📧 Email: #{patient.email}" if patient.email.present?
    puts "   📞 Phone: #{patient.phone}" if patient.phone.present?
  end

else
  puts "❌ Import service failed!"
  puts "🚨 Errors: #{import_service.errors.join(', ')}"
end

puts "\n🌐 Web Interface URLs:"
puts "   - Health Dashboard: http://localhost:3000/health"
puts "   - Import Page: http://localhost:3000/health/import"
if HealthPatient.any?
  puts "   - Patient Details: http://localhost:3000/health/1"
end

puts "\n" + "=" * 50
puts "Test completed! You can now test the web interface."
