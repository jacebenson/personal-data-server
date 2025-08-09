#!/usr/bin/env ruby

# Test script for vCard processor

# Test vCard with prefixed properties
test_vcard = <<~VCARD
BEGIN:VCARD
VERSION:3.0
PRODID:-//Apple Inc.//iOS 12.4//EN
N:Talley;Alex;;;
FN:Alex Talley
ORG:Dads Club;
item1.TEL;type=pref:+19529239481
REV:2019-08-17T03:17:46Z
END:VCARD
VCARD

puts "Testing vCard processor with prefixed properties..."

# Create a test file-like object
class TestFile
  def initialize(content)
    @content = content
  end

  def read
    @content
  end

  def original_filename
    "test.vcf"
  end
end

# Create a test user (you'll need to replace this with an actual user ID)
user = User.first || User.create!(
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123"
)

test_file = TestFile.new(test_vcard)
processor = VcardProcessor.new(test_file, user)

puts "Processing vCard..."
result = processor.process

puts "Result: #{result}"

if result[:count] > 0
  contact = user.contacts.last
  puts "\nCreated contact:"
  puts "Name: #{contact.full_name}"
  puts "Organization: #{contact.organization}"
  puts "Phones: #{contact.phones}"
  puts "Emails: #{contact.emails}"
  puts "UID: #{contact.uid}"
else
  puts "No contacts created!"
  puts "Errors: #{result[:errors]}" if result[:errors].any?
end
