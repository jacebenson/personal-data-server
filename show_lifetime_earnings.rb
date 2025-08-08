#!/usr/bin/env ruby

require_relative 'config/environment'

user = User.first
earnings = user.social_security_earnings.order(:year)

puts "=== Your Lifetime Social Security Earnings Summary ==="
puts "Total Years: #{earnings.count}"
puts "Years Covered: #{earnings.first.year} - #{earnings.last.year}"
puts

total_fica = earnings.sum(:fica_earnings)
total_medicare = earnings.sum(:medicare_earnings)

puts "Total FICA Earnings: $#{total_fica.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Total Medicare Earnings: $#{total_medicare.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts

puts "=== Year by Year Breakdown ==="
earnings.each do |record|
  fica_formatted = record.fica_earnings.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  medicare_formatted = record.medicare_earnings.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  puts "#{record.year}: FICA $#{fica_formatted.rjust(10)}, Medicare $#{medicare_formatted.rjust(10)}"
end

puts
puts "=== Career Progression Highlights ==="
peak_year = earnings.max_by(&:fica_earnings)
puts "Peak Earning Year: #{peak_year.year} with $#{peak_year.fica_earnings.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

recent_avg = earnings.last(5).sum(&:fica_earnings) / 5
puts "Last 5 Years Average: $#{recent_avg.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

first_year = earnings.first
puts "Starting Year (#{first_year.year}): $#{first_year.fica_earnings.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Growth Factor: #{(peak_year.fica_earnings / first_year.fica_earnings).round(1)}x"
