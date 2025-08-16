#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'

puts "=== Testing ResMed CPAP Complete Integration ==="
puts

# Check if we have a patient
patient = HealthPatient.first
unless patient
  puts "❌ No patient found. Please import health data first."
  exit 1
end

puts "👤 Testing with patient: #{patient.full_name}"

# Create a more comprehensive test CSV file
sample_csv_path = Rails.root.join('tmp', 'SLEEP_RECORD.csv')

sample_csv_content = <<~CSV
PATIENT_ID,SORT_KEY,USAGE_HOURS,FG_SERIAL_NO,SESSION_DATE,MODE,SLEEP_SCORE,AHI_SCORE,LEAK_SCORE,MASK_SCORE,USAGE_SCORE,MASK_SESSION_COUNT,AHI,LEAK_50_PERCENTILE,LEAK_70_PERCENTILE,LEAK_95_PERCENTILE,EXPIRATION_TIMESTAMP,EVENTID,EVENTNAME,EVENTVERSION,EVENTSOURCE,AWSREGION,EVENTSOURCEARN,APPROXIMATECREATIONDATETIME,SEQUENCENUMBER,SIZEBYTES,STREAMVIEWTYPE,RECORD_DELETE_IND,DATA_LOAD_SOURCE,DATA_UPDATE_SOURCE,DATA_LOAD_TIME,DATA_UPDATE_TIME,RECORD_MD5,RECORD_ARCHIVE_IND,SOURCE_SYSTEM_ID,SOURCE,IS_PHI,RECEIVE_TIMESTAMP,HASH_SORT_KEY_SAFE_HARBOR,HASH_PATIENT_ID_SAFE_HARBOR,HASH_SERIAL_NUMBER_SAFE_HARBOR
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-15,7.25,23212591963,2024-08-15T00:00:00.000Z,AutoSet,85,4,18,4,73,1,1.8,0.0,0.0,0.0,2024-08-20T00:00:00.000Z,test_event_id,TEST,1.0,test,us-west-2,test_arn,2024-08-16T00:00:00.000Z,12345,400,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-16T00:00:00.000Z,2024-08-16T00:00:00.000Z,test_hash,N,13,TEST,TEST,TEST,test_hash_1,test_hash_2,test_hash_3
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-14,6.50,23212591963,2024-08-14T00:00:00.000Z,AutoSet,78,5,15,3,65,1,3.2,0.0,0.0,2.1,2024-08-19T00:00:00.000Z,test_event_id_2,TEST,1.0,test,us-west-2,test_arn,2024-08-15T00:00:00.000Z,12346,401,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-15T00:00:00.000Z,2024-08-15T00:00:00.000Z,test_hash_2,N,13,TEST,TEST,TEST,test_hash_4,test_hash_5,test_hash_6
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-13,8.75,23212591963,2024-08-13T00:00:00.000Z,AutoSet,92,3,20,5,88,1,0.5,0.0,0.0,0.0,2024-08-18T00:00:00.000Z,test_event_id_3,TEST,1.0,test,us-west-2,test_arn,2024-08-14T00:00:00.000Z,12347,402,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-14T00:00:00.000Z,2024-08-14T00:00:00.000Z,test_hash_3,N,13,TEST,TEST,TEST,test_hash_7,test_hash_8,test_hash_9
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-12,3.25,23212591963,2024-08-12T00:00:00.000Z,AutoSet,45,15,10,2,32,1,12.8,0.0,0.0,8.5,2024-08-17T00:00:00.000Z,test_event_id_4,TEST,1.0,test,us-west-2,test_arn,2024-08-13T00:00:00.000Z,12348,403,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-13T00:00:00.000Z,2024-08-13T00:00:00.000Z,test_hash_4,N,13,TEST,TEST,TEST,test_hash_10,test_hash_11,test_hash_12
00uapy9pfhvm6KHrd297,SLEEP_RECORD#2024-08-11,5.85,23212591963,2024-08-11T00:00:00.000Z,AutoSet,65,8,12,3,58,1,8.2,0.0,0.0,5.2,2024-08-16T00:00:00.000Z,test_event_id_5,TEST,1.0,test,us-west-2,test_arn,2024-08-12T00:00:00.000Z,12349,404,NEW_AND_OLD_IMAGES,N,TEST,TEST,2024-08-12T00:00:00.000Z,2024-08-12T00:00:00.000Z,test_hash_5,N,13,TEST,TEST,TEST,test_hash_13,test_hash_14,test_hash_15
CSV

File.write(sample_csv_path, sample_csv_content)
puts "📄 Created comprehensive test CSV at: #{sample_csv_path}"
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

  # Show recent sleep data with detailed analysis
  if HealthSleepData.any?
    puts "\n😴 Recent Sleep Sessions (detailed analysis):"
    HealthSleepData.order(session_date: :desc).limit(5).each do |session|
      puts "   - #{session.formatted_date}:"
      puts "     Usage: #{session.usage_hours_display} (#{session.compliance_status})"
      puts "     AHI: #{session.ahi} (#{session.ahi_severity})"
      puts "     Sleep Score: #{session.sleep_score} (#{session.sleep_quality_indicator})"
      puts "     Mask Fit: #{session.mask_score} (#{session.mask_fit_status})"
      puts "     Leak: #{session.leak_score} (#{session.leak_status})"
      puts "     Overall Therapy: #{session.overall_therapy_effectiveness}"
      puts
    end

    # Calculate some summary stats
    total_sessions = HealthSleepData.count
    compliant_sessions = HealthSleepData.good_compliance.count
    compliance_rate = (compliant_sessions.to_f / total_sessions * 100).round(1)
    avg_usage = HealthSleepData.where.not(usage_hours: nil).average(:usage_hours)&.round(2)
    avg_ahi = HealthSleepData.where.not(ahi: nil).average(:ahi)&.round(2)
    avg_score = HealthSleepData.where.not(sleep_score: nil).average(:sleep_score)&.round(1)

    puts "📈 Summary Statistics:"
    puts "   - Total Sessions: #{total_sessions}"
    puts "   - Compliance Rate: #{compliance_rate}% (#{compliant_sessions}/#{total_sessions} sessions ≥4h)"
    puts "   - Average Usage: #{avg_usage} hours" if avg_usage
    puts "   - Average AHI: #{avg_ahi}" if avg_ahi
    puts "   - Average Sleep Score: #{avg_score}" if avg_score
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
