#!/usr/bin/env ruby

puts "=== Weight Conversion Test ==="
puts

test_weight_lbs = 358

# Method 1: Multiply by 0.453592
kg_method1 = test_weight_lbs * 0.453592
puts "Method 1 (multiply by 0.453592): #{test_weight_lbs} lbs = #{kg_method1.round(4)} kg"

# Method 2: Divide by 2.20462
kg_method2 = test_weight_lbs / 2.20462
puts "Method 2 (divide by 2.20462): #{test_weight_lbs} lbs = #{kg_method2.round(4)} kg"

# What would give us 167.9 kg?
wrong_factor = 167.9 / 358.0
puts "Wrong factor that gives 167.9 kg: #{wrong_factor.round(6)}"

puts
puts "Correct conversion: 358 lbs = #{kg_method1.round(2)} kg"
puts "Your expected: 162.39 kg"
puts "What you saw: 167.9 kg"
