# Calendar Data Seeds
# Creates sample calendar and event data

def seed_calendar_data(user)
  puts "📅 Seeding calendar data for #{user.email}..."

  # Create sample calendars
  calendars = [
    {
      name: "Personal",
      description: "Personal events and appointments",
      color: "#3B82F6",
      source_type: "manual",
      active: true
    },
    {
      name: "Work",
      description: "Work meetings and deadlines",
      color: "#EF4444",
      source_type: "manual",
      active: true
    },
    {
      name: "Health",
      description: "Medical appointments and health reminders",
      color: "#10B981",
      source_type: "manual",
      active: true
    },
    {
      name: "Family",
      description: "Family events and gatherings",
      color: "#F59E0B",
      source_type: "manual",
      active: true
    }
  ]

  calendar_objects = []
  calendars.each do |cal_data|
    calendar = Calendar.find_or_create_by!(
      user: user,
      name: cal_data[:name]
    ) do |c|
      c.description = cal_data[:description]
      c.color = cal_data[:color]
      c.source_type = cal_data[:source_type]
      c.active = cal_data[:active]
    end
    calendar_objects << calendar
  end

  personal_cal, work_cal, health_cal, family_cal = calendar_objects

  # Create sample events
  events = [
    # Personal calendar events
    {
      calendar: personal_cal,
      uid: "personal-workout-#{Date.current.strftime('%Y%m%d')}",
      summary: "Morning Workout",
      description: "Gym session - upper body workout",
      location: "Local Gym",
      start_time: Date.current + 1.day + 7.hours,
      end_time: Date.current + 1.day + 8.hours,
      all_day_event: false,
      status: "confirmed"
    },
    {
      calendar: personal_cal,
      uid: "personal-grocery-#{(Date.current + 2.days).strftime('%Y%m%d')}",
      summary: "Grocery Shopping",
      description: "Weekly grocery run",
      location: "Whole Foods",
      start_time: Date.current + 2.days + 10.hours,
      end_time: Date.current + 2.days + 11.hours,
      all_day_event: false,
      status: "tentative"
    },
    {
      calendar: personal_cal,
      uid: "personal-birthday-#{(Date.current + 10.days).strftime('%Y%m%d')}",
      summary: "Mom's Birthday",
      description: "Remember to call mom!",
      start_time: Date.current + 10.days,
      end_time: Date.current + 10.days,
      all_day_event: true,
      status: "confirmed"
    },

    # Work calendar events
    {
      calendar: work_cal,
      uid: "work-standup-#{Date.current.strftime('%Y%m%d')}",
      summary: "Daily Standup",
      description: "Team sync meeting",
      location: "Conference Room A",
      start_time: Date.current + 1.day + 9.hours,
      end_time: Date.current + 1.day + 9.hours + 30.minutes,
      all_day_event: false,
      status: "confirmed",
      organizer_email: "manager@company.com",
      organizer_name: "Project Manager",
      attendee_emails: "dev1@company.com,dev2@company.com,dev3@company.com"
    },
    {
      calendar: work_cal,
      uid: "work-review-#{(Date.current + 3.days).strftime('%Y%m%d')}",
      summary: "Code Review Session",
      description: "Review pull requests and architecture decisions",
      location: "Zoom Meeting",
      start_time: Date.current + 3.days + 14.hours,
      end_time: Date.current + 3.days + 15.hours,
      all_day_event: false,
      status: "confirmed",
      organizer_email: "lead@company.com",
      organizer_name: "Tech Lead"
    },
    {
      calendar: work_cal,
      uid: "work-deadline-#{(Date.current + 7.days).strftime('%Y%m%d')}",
      summary: "Project Deadline",
      description: "Final deadline for Q4 feature release",
      start_time: Date.current + 7.days,
      end_time: Date.current + 7.days,
      all_day_event: true,
      status: "confirmed"
    },

    # Health calendar events
    {
      calendar: health_cal,
      uid: "health-checkup-#{(Date.current + 14.days).strftime('%Y%m%d')}",
      summary: "Annual Physical",
      description: "Yearly checkup with Dr. Smith",
      location: "Main Street Medical Center",
      start_time: Date.current + 14.days + 10.hours,
      end_time: Date.current + 14.days + 11.hours,
      all_day_event: false,
      status: "confirmed",
      organizer_email: "appointments@medical.com",
      organizer_name: "Medical Center"
    },
    {
      calendar: health_cal,
      uid: "health-dentist-#{(Date.current + 21.days).strftime('%Y%m%d')}",
      summary: "Dental Cleaning",
      description: "6-month dental cleaning and checkup",
      location: "Smile Dental Care",
      start_time: Date.current + 21.days + 14.hours,
      end_time: Date.current + 21.days + 15.hours,
      all_day_event: false,
      status: "confirmed"
    },
    {
      calendar: health_cal,
      uid: "health-medication-reminder",
      summary: "Medication Reminder",
      description: "Take evening medications",
      start_time: Date.current + 20.hours,
      end_time: Date.current + 20.hours + 15.minutes,
      all_day_event: false,
      status: "confirmed",
      recurrence_rule: "FREQ=DAILY;INTERVAL=1"
    },

    # Family calendar events
    {
      calendar: family_cal,
      uid: "family-dinner-#{(Date.current + 5.days).strftime('%Y%m%d')}",
      summary: "Family Dinner",
      description: "Monthly family gathering at parents' house",
      location: "Parents' House",
      start_time: Date.current + 5.days + 18.hours,
      end_time: Date.current + 5.days + 21.hours,
      all_day_event: false,
      status: "confirmed"
    },
    {
      calendar: family_cal,
      uid: "family-vacation-#{(Date.current + 30.days).strftime('%Y%m%d')}",
      summary: "Summer Vacation",
      description: "Week-long family vacation to the beach",
      location: "Beach Resort, FL",
      start_time: Date.current + 30.days,
      end_time: Date.current + 37.days,
      all_day_event: true,
      status: "tentative"
    },

    # Some past events for history
    {
      calendar: work_cal,
      uid: "work-meeting-past-1",
      summary: "Team Retrospective",
      description: "Sprint retrospective meeting",
      location: "Conference Room B",
      start_time: 3.days.ago + 15.hours,
      end_time: 3.days.ago + 16.hours,
      all_day_event: false,
      status: "confirmed"
    },
    {
      calendar: personal_cal,
      uid: "personal-movie-past",
      summary: "Movie Night",
      description: "Watched the latest Marvel movie",
      location: "AMC Theater",
      start_time: 7.days.ago + 19.hours,
      end_time: 7.days.ago + 22.hours,
      all_day_event: false,
      status: "confirmed"
    }
  ]

  events.each do |event_data|
    CalendarEvent.find_or_create_by!(
      user: user,
      uid: event_data[:uid],
      calendar_name: event_data[:calendar]&.name || "Personal"
    ) do |event|
      event.calendar = event_data[:calendar]
      event.summary = event_data[:summary]
      event.description = event_data[:description]
      event.location = event_data[:location]
      event.start_time = event_data[:start_time]
      event.end_time = event_data[:end_time]
      event.all_day_event = event_data[:all_day_event]
      event.status = event_data[:status]
      event.organizer_email = event_data[:organizer_email]
      event.organizer_name = event_data[:organizer_name]
      event.attendee_emails = event_data[:attendee_emails]
      event.recurrence_rule = event_data[:recurrence_rule]
    end
  end

  puts "   ✅ Created #{Calendar.where(user: user).count} calendars"
  puts "   ✅ Created #{CalendarEvent.where(user: user).count} calendar events"
  puts "   ✅ Upcoming events: #{CalendarEvent.where(user: user).where('start_time > ?', Time.current).count}"
  puts "   ✅ Past events: #{CalendarEvent.where(user: user).where('start_time <= ?', Time.current).count}"
end
