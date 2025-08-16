#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Testing Medication Date Formatting and Sorting ==="
puts

# Get the first patient
patient = HealthPatient.first
unless patient
  puts "No patient found. Please import some health data first."
  exit
end

puts "Patient: #{patient.full_name}"
puts

# Show all medications with their dates and status
medications = patient.health_medications.order(Arel.sql("
  CASE status
    WHEN 'active' THEN 1
    WHEN 'completed' THEN 2
    WHEN 'missed' THEN 3
    ELSE 4
  END,
  start_date DESC
"))

puts "All Medications (sorted by status priority, then date descending):"
puts "=" * 70

medications.each_with_index do |med, index|
  puts "#{index + 1}. #{med.medication_name} #{med.dosage}"
  puts "   Status: #{med.status}"
  puts "   Start Date (raw): #{med.start_date}"
  puts "   Start Date (formatted): #{med.formatted_start_date}"
  puts "   End Date (formatted): #{med.formatted_end_date}" if med.end_date.present?
  puts "   Frequency: #{med.frequency}" if med.frequency.present?
  puts "   Prescriber: #{med.prescriber}" if med.prescriber.present?
  puts "   Shotsy injection?: #{med.shotsy_injection?}"
  puts "   Status priority: #{med.status_priority}"
  puts
end

puts "Active medications count: #{patient.health_medications.where(status: 'active').count}"
puts "Completed injections count: #{patient.health_medications.where(status: 'completed').count}"
puts "Missed injections count: #{patient.health_medications.where(status: 'missed').count}"

puts
puts "Testing date parsing with different formats:"
test_dates = [
  "2025-08-15",     # ISO format (Shotsy)
  "08/15/2025",     # US format
  "2025-02-15",     # Another ISO format
  "12/21/2022"      # Another US format
]

test_dates.each do |date_str|
  # Create a dummy medication object to test the method
  med = HealthMedication.new
  formatted = med.parse_and_format_date(date_str)
  puts "#{date_str} → #{formatted}"
end
