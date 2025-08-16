#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Testing ResMed CPAP Import Service ==="
puts

# Check if we have a patient
patient = HealthPatient.first
unless patient
  puts "❌ No patient found. Please import health data first."
  exit 1
end

puts "👤 Testing with patient: #{patient.full_name}"
puts

# Create a sample CSV file for testing
sample_csv_path = Rails.root.join('tmp', 'sample_resmed_data.csv')

sample_csv_content = <<~CSV
PATIENT_ID,SORT_KEY,USAGE_HOURS,FG_SERIAL_NO,SESSION_DATE,MODE,SLEEP_SCORE,AHI_SCORE,LEAK_SCORE,MASK_SCORE,USAGE_SCORE,MASK_SESSION_COUNT,AHI,LEAK_50_PERCENTILE,LEAK_70_PERCENTILE,LEAK_95_PERCENTILE,EXPIRATION_TIMESTAMP,EVENTID,EVENTNAME,EVENTVERSION,EVENTSOURCE,AWSREGION,EVENTSOURCEARN,APPROXIMATECREATIONDATETIME,SEQUENCENUMBER,SIZEBYTES,STREAMVIEWTYPE,RECORD_DELETE_IND,DATA_LOAD_SOURCE,DATA_UPDATE_SOURCE,DATA_LOAD_TIME,DATA_UPDATE_TIME,RECORD_MD5,RECORD_ARCHIVE_IND,SOURCE_SYSTEM_ID,SOURCE,IS_PHI,RECEIVE_TIMESTAMP,HASH_SORT_KEY_SAFE_HARBOR,HASH_PATIENT_ID_SAFE_HARBOR,HASH_SERIAL_NUMBER_SAFE_HARBOR
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-15,7.25,23212591963,2024-08-15T00:00:00.000Z,AutoSet,85,4,18,4,73,1,1.8,0.0,0.0,0.0,2024-08-20T00:00:00.000Z,test_event_id,TEST,1.0,test,us-west-2,test_arn,2024-08-16T00:00:00.000Z,12345,400,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-16T00:00:00.000Z,2024-08-16T00:00:00.000Z,test_hash,N,13,TEST,TEST,TEST,test_hash_1,test_hash_2,test_hash_3
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-14,6.50,23212591963,2024-08-14T00:00:00.000Z,AutoSet,78,5,15,3,65,1,3.2,0.0,0.0,2.1,2024-08-19T00:00:00.000Z,test_event_id_2,TEST,1.0,test,us-west-2,test_arn,2024-08-15T00:00:00.000Z,12346,401,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-15T00:00:00.000Z,2024-08-15T00:00:00.000Z,test_hash_2,N,13,TEST,TEST,TEST,test_hash_4,test_hash_5,test_hash_6
CSV

File.write(sample_csv_path, sample_csv_content)
puts "📄 Created sample CSV at: #{sample_csv_path}"
puts

# Test the import service
import_service = ResmedCpapImportService.new

puts "🔄 Starting import..."
start_time = Time.current

success = import_service.import_from_csv(sample_csv_path)

end_time = Time.current
puts "\n" + "=" * 60

if success
  puts "✅ ResMed CPAP import completed successfully!"
  puts "📊 Import Summary:"
  puts "   - Time taken: #{(end_time - start_time).round(2)} seconds"

  summary = import_service.summary
  summary.each do |key, count|
    next if count == 0
    puts "   - #{key.to_s.humanize}: #{count}"
  end

  puts "\n📋 Sleep Data in Database:"
  puts "   - Total Sleep Sessions: #{HealthSleepData.count}"

  # Show recent sleep data
  if HealthSleepData.any?
    puts "\n😴 Recent Sleep Sessions:"
    HealthSleepData.order(session_date: :desc).limit(3).each do |session|
      puts "   - #{session.formatted_date}: #{session.usage_hours_display}, AHI: #{session.ahi}, Score: #{session.sleep_score}"
      puts "     Compliance: #{session.compliance_status}, Quality: #{session.sleep_quality_indicator}"
    end
  end

else
  puts "❌ Import service failed!"
  puts "🚨 Errors: #{import_service.errors.join(', ')}"
end

puts "\n🌐 View your sleep data at:"
puts "   - Health Dashboard: http://localhost:3000/health"

# Clean up test file
File.delete(sample_csv_path) if File.exist?(sample_csv_path)
puts "\n🧹 Cleaned up test file"
