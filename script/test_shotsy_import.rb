#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Testing Shotsy CSV Import ==="
puts

# Create a test CSV file with your sample data
test_csv_content = <<~CSV
Date,Avg Level (mg),Shot,Time,Site,Pain Level,Taken,Shot Notes,Recorded Weight (lbs),Calories,Protein (g),Food Noise,Heartburn,Nausea,Suppressed Appetite,Day Notes
2025-02-15,0.05,"Semaglutide 0.25mg","18:05","Stomach - Upper Left","0.0","Yes","",,,,,,,,""
2025-02-16,0.20,"","","","","","",,,,,,,,""
2025-02-17,0.25,"Semaglutide 0.25mg","18:00","Stomach - Upper Right","1.0","Yes","Slight soreness",180.5,1200,45,"No","No","Yes","Yes","Feeling good today"
CSV

# Create temp file
temp_dir = Rails.root.join("tmp", "health_uploads")
FileUtils.mkdir_p(temp_dir)
test_file_path = temp_dir.join("test_shotsy_import.csv")

File.write(test_file_path, test_csv_content)

puts "Created test CSV file: #{test_file_path}"
puts "Content:"
puts test_csv_content
puts

# Make sure we have a patient to work with
patient = HealthPatient.first
unless patient
  puts "Creating test patient..."
  patient = HealthPatient.create!(
    first_name: "Test",
    last_name: "Patient",
    birth_date: "1990-01-01",
    gender: "male"
  )
  puts "Created patient: #{patient.full_name}"
end

puts "Using patient: #{patient.full_name}"
puts

# Test the import
puts "Testing Shotsy import service..."
import_service = ShotsyImportService.new
success = import_service.import_from_csv(test_file_path.to_s)

puts "Import result: #{success ? 'SUCCESS' : 'FAILED'}"
puts "Summary: #{import_service.summary}"

if import_service.errors.any?
  puts "Errors:"
  import_service.errors.each do |error|
    puts "  - #{error}"
  end
end

puts

# Show what was imported
puts "=== Import Results ==="
puts

if HealthVitalSign.any?
  puts "Vital Signs Records:"
  HealthVitalSign.order(:measurement_date).each do |vs|
    puts "  #{vs.measurement_date}: Weight #{vs.weight} kg" if vs.weight.present?
  end
  puts
end

if HealthMedication.any?
  puts "Medication Records:"
  HealthMedication.order(:start_date).each do |med|
    puts "  #{med.medication_name} #{med.dosage} - #{med.status} (#{med.start_date})"
  end
  puts
end

if HealthEncounter.any?
  puts "Encounter Records:"
  HealthEncounter.where(encounter_type: "Shotsy App Tracking").order(:encounter_date).each do |enc|
    puts "  #{enc.encounter_date}: #{enc.reason_for_visit}"
  end
  puts
end

# Clean up
File.delete(test_file_path) if File.exist?(test_file_path)
puts "Test completed. Temp file cleaned up."
