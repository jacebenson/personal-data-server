#!/usr/bin/env ruby

# Script to create a test calendar event for today
# Usage: ruby script/create_test_event.rb

require_relative '../config/environment'

# Get the user and their timezone setting
user = User.find(1)
Time.zone = user.user_timezone

# Get today's date in user's timezone
today = Time.zone.today
date_string = today.strftime('%Y-%m-%d')

# Set up event times (10 AM to 11 AM today in user's timezone)
start_time = Time.zone.parse("#{today} 10:00 AM")  # 10 AM today in user's timezone
end_time = start_time + 1.hour  # 1 hour duration

# Create the event
begin
  calendar_event = CalendarEvent.create!(
    user_id: 1,
    uid: "test-event-#{date_string}-#{SecureRandom.hex(8)}",
    summary: "Testing Event #{date_string}",
    description: "This is a test event created for #{today.strftime('%B %d, %Y')} to demo the calendar partial functionality.",
    location: "Home Office",
    start_time: start_time,
    end_time: end_time,
    all_day_event: false,
    calendar_name: "Personal",
    status: "confirmed",
    categories: "work, demo, testing"
  )

  puts "✅ Successfully created calendar event!"
  puts "   Title: #{calendar_event.summary}"
  puts "   Date: #{calendar_event.start_time.strftime('%B %d, %Y')}"
  puts "   Time: #{calendar_event.start_time.strftime('%l:%M %p')} - #{calendar_event.end_time.strftime('%l:%M %p')}"
  puts "   Timezone: #{user.user_timezone}"
  puts "   Location: #{calendar_event.location}"
  puts "   Calendar: #{calendar_event.calendar_name}"
  puts "   Event ID: #{calendar_event.id}"
  puts "   UID: #{calendar_event.uid}"

rescue ActiveRecord::RecordInvalid => e
  puts "❌ Failed to create calendar event:"
  puts "   Error: #{e.message}"
  e.record.errors.full_messages.each do |error|
    puts "   - #{error}"
  end
rescue => e
  puts "❌ Unexpected error creating calendar event:"
  puts "   Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end
