#!/usr/bin/env ruby

# Add the Rails environment
require File.expand_path('../config/environment', __dir__)

# Create a test user (or use existing one)
user = User.first
if user.nil?
  puts "No users found. Please create a user first."
  exit 1
end

puts "Testing Goodreads data processor with user: #{user.id}"

# Test with the actual CSV file
csv_file_path = Rails.root.join('goodreads_library_export.csv')

unless File.exist?(csv_file_path)
  puts "CSV file not found at: #{csv_file_path}"
  exit 1
end

puts "Processing CSV file: #{csv_file_path}"
puts "File size: #{File.size(csv_file_path)} bytes"

# Create processor and test
processor = Entertainment::GoodreadsDataProcessor.new(csv_file_path, user)

# First validate headers
validation = Entertainment::GoodreadsDataProcessor.validate_headers(csv_file_path)
puts "\nHeader validation:"
puts "Valid: #{validation[:valid]}"
if validation[:found_headers]
  puts "Found headers: #{validation[:found_headers].first(5).join(', ')}..." # Show first 5
  puts "Total headers: #{validation[:found_headers].length}"
end
if validation[:missing_headers]
  puts "Missing headers: #{validation[:missing_headers].join(', ')}"
end
if validation[:total_rows]
  puts "Total rows: #{validation[:total_rows]}"
end

# Process the file
puts "\nProcessing file..."
result = processor.process

puts "\nResults:"
puts "Success: #{result[:success]}"
puts "Processed: #{result[:count]} records"
puts "Skipped: #{result[:skipped]} records"

if result[:errors].any?
  puts "\nErrors:"
  result[:errors].each { |error| puts "  - #{error}" }
end

# Show some sample records
puts "\nSample Goodreads records:"
user.entertainment_contents.goodreads.limit(3).each do |book|
  puts "  #{book.title} by #{book.author} (#{book.exclusive_shelf})"
end

puts "\nTotal Goodreads records: #{user.entertainment_contents.goodreads.count}"
