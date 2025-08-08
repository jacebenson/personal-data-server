#!/usr/bin/env ruby

# Add the Rails app to the load path
require_relative 'config/environment'

puts "=== Social Security Processor Debug ==="
puts "Time: #{Time.current}"
puts

# Get the first user
user = User.first
puts "User: #{user.id} (#{user.email})"
puts

# Test file path
file_path = '/home/jace/git/personal-data-server/tmp/social-security-statement.xml'
puts "File path: #{file_path}"
puts "File exists: #{File.exist?(file_path)}"
puts "File readable: #{File.readable?(file_path)}"
puts

# Test XML parsing directly first
puts "=== Direct XML Test ==="
begin
  doc = Nokogiri::XML(File.open(file_path))
  puts "XML parsed successfully"

  # Test namespace detection
  root = doc.root
  puts "Root element: #{root.name}"
  puts "Root namespace: #{root.namespace.href if root.namespace}"

  # Test different XPath queries
  puts "\n=== XPath Tests ==="

  # Test 1: Without namespace
  records1 = doc.xpath('//Earnings')
  puts "Without namespace: #{records1.length} records"

  # Test 2: With correct namespace
  records2 = doc.xpath('//osss:Earnings', 'osss' => 'http://ssa.gov/osss/schemas/2.0')
  puts "With correct namespace: #{records2.length} records"

  # Test 3: With old namespace (what was wrong)
  records3 = doc.xpath('//osss:Earnings', 'osss' => 'http://www.ssa.gov/osss')
  puts "With old namespace: #{records3.length} records"

  if records2.length > 0
    puts "\n=== Sample Record ==="
    sample = records2.first
    puts "Start Year: #{sample['startYear']}"
    puts "End Year: #{sample['endYear']}"

    fica = sample.at_xpath('osss:FicaEarnings', 'osss' => 'http://ssa.gov/osss/schemas/2.0')
    medicare = sample.at_xpath('osss:MedicareEarnings', 'osss' => 'http://ssa.gov/osss/schemas/2.0')

    puts "FICA Earnings: #{fica&.text}"
    puts "Medicare Earnings: #{medicare&.text}"
  end

rescue => e
  puts "XML parsing error: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== Processor Test ==="
# Test the actual processor
processor = SocialSecurityProcessor.new(user, file_path)
puts "Processor initialized"

# Check current count before processing
before_count = user.social_security_earnings.count
puts "Existing records before: #{before_count}"

# Run the processor
result = processor.process
puts "Processing result: #{result}"
puts "Processor errors: #{processor.errors}" unless processor.errors.empty?

# Check count after processing
after_count = user.social_security_earnings.count
puts "Records after: #{after_count}"
puts "Records imported: #{after_count - before_count}"

if after_count > 0
  puts "\n=== Sample Records ==="
  user.social_security_earnings.order(:year).limit(5).each do |record|
    puts "#{record.year}: FICA $#{record.fica_earnings}, Medicare $#{record.medicare_earnings}"
  end

  if after_count > 5
    puts "... and #{after_count - 5} more records"
  end
end

puts "\n=== Debug Complete ==="
