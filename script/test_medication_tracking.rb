#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Testing Updated Shotsy Medication Tracking ==="
puts

# Create a test CSV with different dosages and injection scenarios
test_csv_content = <<~CSV
Date,Avg Level (mg),Shot,Time,Site,Pain Level,Taken,Shot Notes,Recorded Weight (lbs),Calories,Protein (g),Food Noise,Heartburn,Nausea,Suppressed Appetite,Day Notes
2025-08-01,0.25,"Semaglutide 0.25mg","18:05","Stomach - Upper Left","0.0","Yes","Starting dose",,,,,,,,""
2025-08-08,0.25,"Semaglutide 0.25mg","18:00","Stomach - Upper Right","1.0","Yes","Second week",180.5,1200,45,"No","No","Yes","Yes","Feeling good"
2025-08-15,0.50,"Semaglutide 0.50mg","18:15","Thigh - Left","2.0","Yes","Increased dose",,,,,,,,""
2025-08-22,0.50,"Semaglutide 0.50mg","18:00","Thigh - Right","1.5","No","Missed injection",,,,,,,,""
2025-08-29,0.50,"Semaglutide 0.50mg","18:30","Stomach - Lower","0.5","Yes","Back on track",,,,,,,,""
CSV

# Create temp file
temp_dir = Rails.root.join("tmp", "health_uploads")
FileUtils.mkdir_p(temp_dir)
test_file_path = temp_dir.join("test_shotsy_medication_tracking.csv")

File.write(test_file_path, test_csv_content)

puts "Created test CSV with dosage progression:"
puts test_csv_content
puts

# Make sure we have a patient
patient = HealthPatient.first
unless patient
  patient = HealthPatient.create!(
    first_name: "Test",
    last_name: "Patient", 
    birth_date: "1990-01-01",
    gender: "male"
  )
end

puts "Using patient: #{patient.full_name}"
puts

# Test the import
puts "Testing updated Shotsy import service..."
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

# Show the medication records that were created
puts "=== Medication Records Created ==="
recent_medications = HealthMedication.where('start_date >= ?', '2025-08-01').order(:start_date)

recent_medications.each do |med|
  puts "#{med.start_date}: #{med.medication_name} #{med.dosage}"
  puts "  Status: #{med.status}"
  puts "  Frequency: #{med.frequency}"
  puts "  Route: #{med.route}"
  puts "  Prescriber: #{med.prescriber}" if med.prescriber.present?
  puts
end

puts "=== Encounter Records ==="
recent_encounters = HealthEncounter.where(encounter_type: "Shotsy Injection Tracking")
                                  .where('encounter_date >= ?', '2025-08-01')
                                  .order(:encounter_date)

recent_encounters.each do |enc|
  puts "#{enc.encounter_date}: #{enc.reason_for_visit}"
  puts "  Provider: #{enc.provider_name}"
  if enc.diagnosis.present?
    puts "  Details:"
    enc.diagnosis.split("\n").each do |line|
      puts "    #{line}"
    end
  end
  puts
end

# Clean up
File.delete(test_file_path) if File.exist?(test_file_path)
puts "Test completed!"
