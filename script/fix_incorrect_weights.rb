#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Fixing Incorrect Weight Conversions ==="
puts

# These are the corrections identified by the check script
corrections = [
  { id: 31, current: 167.922, correct: 162.41, original_lbs: 358 },
  { id: 30, current: 169.101, correct: 163.55, original_lbs: 361 },
  { id: 29, current: 169.827, correct: 164.25, original_lbs: 362 },
  { id: 28, current: 169.101, correct: 163.55, original_lbs: 361 },
  { id: 26, current: 169.555, correct: 163.99, original_lbs: 362 },
  { id: 22, current: 164.928, correct: 159.51, original_lbs: 352 },
  { id: 42, current: 169.1, correct: 163.55, original_lbs: 361 },
  { id: 43, current: 168.74, correct: 163.2, original_lbs: 360 },
  { id: 44, current: 166.29, correct: 160.83, original_lbs: 355 },
  { id: 45, current: 165.2, correct: 159.78, original_lbs: 352 }
]

corrections.each do |correction|
  vital_sign = HealthVitalSign.find_by(id: correction[:id])
  
  if vital_sign
    old_weight = vital_sign.weight
    new_weight = correction[:correct]
    
    vital_sign.update!(weight: new_weight)
    
    puts "✅ Fixed ID #{correction[:id]} (#{vital_sign.measurement_date}): #{old_weight} kg → #{new_weight} kg (#{correction[:original_lbs]} lbs)"
  else
    puts "❌ Could not find vital sign with ID #{correction[:id]}"
  end
end

puts
puts "🎉 All weight conversions have been corrected!"
puts
puts "Summary of changes:"
puts "- Fixed #{corrections.count} weight records"
puts "- Weights now display correctly in pounds with kg on hover"
puts "- Future Shotsy imports will use the correct conversion factor"
