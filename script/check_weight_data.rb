#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Checking Weight Data for Conversion Issues ==="
puts

# Find vital signs with weight data
vitals_with_weight = HealthVitalSign.where.not(weight: nil).order(:measurement_date)

if vitals_with_weight.empty?
  puts "No weight data found in the database."
  exit
end

puts "Checking #{vitals_with_weight.count} weight records..."
puts

corrections_needed = []

vitals_with_weight.each do |vital|
  current_kg = vital.weight.to_f
  
  # Calculate what the display would show in lbs
  display_lbs = (current_kg * 2.20462).round(1)
  
  # If this was 358 lbs incorrectly converted (giving ~167.9 kg)
  # we can detect this by checking if the kg value seems too high
  # For reference: 358 lbs should be ~162.4 kg, not ~167.9 kg
  
  puts "#{vital.measurement_date}: #{current_kg} kg → displays as #{display_lbs} lbs"
  
  # Look for weights that seem suspiciously high (indicating wrong conversion)
  # This is heuristic based on typical weight ranges
  if current_kg > 160 && current_kg < 170 && display_lbs > 360
    # This might be a weight that was converted incorrectly
    # Original might have been around 358 lbs
    estimated_original_lbs = current_kg / 0.468994
    correct_kg = estimated_original_lbs / 2.20462
    
    puts "  ⚠️  POTENTIAL ISSUE: This might be #{estimated_original_lbs.round(0)} lbs incorrectly converted"
    puts "  📝 Should probably be: #{correct_kg.round(2)} kg (#{estimated_original_lbs.round(0)} lbs)"
    
    corrections_needed << {
      vital: vital,
      current_kg: current_kg,
      estimated_original_lbs: estimated_original_lbs.round(0),
      correct_kg: correct_kg.round(2)
    }
  end
end

puts
if corrections_needed.any?
  puts "🔧 CORRECTIONS NEEDED:"
  puts
  
  corrections_needed.each do |correction|
    puts "Date: #{correction[:vital].measurement_date}"
    puts "  Current: #{correction[:current_kg]} kg"
    puts "  Should be: #{correction[:correct_kg]} kg"
    puts "  Original weight: ~#{correction[:estimated_original_lbs]} lbs"
    puts
  end
  
  puts "To fix these automatically, run this in Rails console:"
  puts
  corrections_needed.each do |correction|
    puts "HealthVitalSign.find(#{correction[:vital].id}).update!(weight: #{correction[:correct_kg]})"
  end
else
  puts "✅ All weight data looks correct!"
end
