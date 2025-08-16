#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Testing Weight Display Conversion ==="
puts

# Find or create a test patient
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

# Create test vital signs with different weights
test_weights_kg = [70.0, 80.5, 90.7, 100.2] # kg

test_weights_kg.each_with_index do |weight_kg, index|
  date = (Date.current - index.days).to_s
  
  vital_sign = HealthVitalSign.create!(
    health_patient: patient,
    measurement_date: date,
    weight: weight_kg
  )
  
  puts "Date: #{date}"
  puts "  Weight in kg: #{weight_kg}"
  puts "  Weight in lbs: #{vital_sign.weight_lbs}"
  puts "  Display format: #{vital_sign.weight_display}"
  puts "  With hover (raw): #{vital_sign.weight_with_hover}"
  puts
end

puts "Conversion test completed!"
puts "You can now check the /health page to see weights displayed in pounds."
puts "Hover over the weight values to see the kg equivalent."
