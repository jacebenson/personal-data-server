#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Checking and Fixing Weight Data ==="
puts

# Find all vital signs that might have been imported from Shotsy
# Look for recent vital signs that might have weight data
recent_vitals = HealthVitalSign.where('created_at > ?', 1.week.ago).where.not(weight: nil)

puts "Found #{recent_vitals.count} recent vital sign records with weight data:"
puts

recent_vitals.each do |vital|
  current_kg = vital.weight
  # Convert back to what the original lbs might have been with wrong conversion
  # If it was stored using wrong factor ~0.469, then original_lbs = kg / 0.469
  possible_original_lbs = current_kg / 0.468994
  
  # What it should be in kg with correct conversion
  correct_kg = possible_original_lbs / 2.20462
  
  puts "Date: #{vital.measurement_date}"
  puts "  Current stored weight: #{current_kg} kg (#{(current_kg * 2.20462).round(1)} lbs)"
  puts "  If this came from: #{possible_original_lbs.round(1)} lbs"
  puts "  Should be stored as: #{correct_kg.round(2)} kg"
  
  # Check if this looks like it was converted wrong (difference > 5kg suggests wrong conversion)
  if (current_kg - correct_kg).abs > 5
    puts "  ⚠️  This looks like it was converted incorrectly!"
    
    print "  Fix this record? (y/n): "
    response = gets.chomp.downcase
    
    if response == 'y' || response == 'yes'
      vital.update!(weight: correct_kg.round(2))
      puts "  ✅ Updated weight from #{current_kg} kg to #{correct_kg.round(2)} kg"
    else
      puts "  ⏭️  Skipped"
    end
  else
    puts "  ✅ This weight looks correct"
  end
  
  puts
end

puts "Weight data check completed!"
puts
puts "To prevent future issues, make sure to use the updated Shotsy import service"
puts "which now uses the correct conversion: lbs ÷ 2.20462 = kg"
