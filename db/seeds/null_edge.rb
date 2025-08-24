# Null Edge Attendee Data Seeds
# Creates sample event attendance tracking data

def seed_null_edge_data(user)
  puts "🎯 Seeding null edge attendee data for #{user.email}..."

  # Create attendance data for the past 90 days
  # This appears to be event attendance tracking - maybe for meetups, conferences, or gatherings

  current_date = Date.current

  # Generate realistic attendance patterns
  attendee_data = []

  # Go back 90 days
  (0..89).each do |days_ago|
    date = current_date - days_ago.days

    # Skip some days randomly to make it realistic (not every day has events)
    next if rand < 0.7  # 70% chance of no event on any given day

    # Different patterns based on day of week
    count = case date.wday
    when 0, 6  # Weekend
      # Weekend events tend to be smaller or bigger depending on type
      rand < 0.3 ? rand(5..15) : rand(25..50)
    when 1  # Monday
      # Monday events tend to be smaller
      rand(8..20)
    when 2, 3, 4  # Tuesday-Thursday
      # Weekday events are moderate
      rand(15..35)
    when 5  # Friday
      # Friday events can be larger (happy hours, etc)
      rand(20..45)
    end

    attendee_data << {
      date: date,
      count: count
    }
  end

  # Add some specific notable events
  notable_events = [
    {
      date: 2.weeks.ago.to_date,
      count: 85  # Large conference or meetup
    },
    {
      date: 1.month.ago.to_date,
      count: 120 # Major event
    },
    {
      date: 6.weeks.ago.to_date,
      count: 60  # Workshop or training
    },
    {
      date: 2.months.ago.to_date,
      count: 200 # Annual conference
    }
  ]

  attendee_data.concat(notable_events)

  # Remove duplicates based on date and sort
  attendee_data = attendee_data.uniq { |data| data[:date] }.sort_by { |data| data[:date] }

  # Create the records
  attendee_data.each do |data|
    NullEdgeAttendee.find_or_create_by!(
      user: user,
      date: data[:date]
    ) do |attendee|
      attendee.count = data[:count]
    end
  end

  puts "   ✅ Created #{NullEdgeAttendee.where(user: user).count} attendance records"
  puts "   ✅ Date range: #{NullEdgeAttendee.where(user: user).minimum(:date)} to #{NullEdgeAttendee.where(user: user).maximum(:date)}"
  puts "   ✅ Total attendees tracked: #{NullEdgeAttendee.where(user: user).sum(:count)}"
  puts "   ✅ Average attendance: #{(NullEdgeAttendee.where(user: user).average(:count) || 0).round(1)}"
  puts "   ✅ Largest event: #{NullEdgeAttendee.where(user: user).maximum(:count)} attendees"
end
