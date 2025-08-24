require 'test_helper'

class CalendarTodayPartialTest < ActionView::TestCase
  include ApplicationHelper

  def setup
    @user = User.create!(
      email: "test#{rand(1000)}@example.com",
      password: "password123",
      confirmed_at: Time.current
    )
    
    # Mock current_user method
    def current_user
      @user
    end
  end

  test "calendar today partial renders without events" do
    # Ensure no events for today
    @user.calendar_events.today.destroy_all
    
    rendered = render partial: 'shared/calendar_today'
    
    assert_includes rendered, "No events scheduled for today"
    assert_includes rendered, "Today's Events"
  end

  test "calendar today partial renders with events" do
    # Create a test event for today
    calendar = @user.calendars.create!(
      name: "Test Calendar",
      url: "https://example.com/test.ics"
    )
    
    @user.calendar_events.create!(
      uid: "test-event-123",
      summary: "Test Meeting",
      start_time: Time.current.beginning_of_day + 14.hours,
      end_time: Time.current.beginning_of_day + 15.hours,
      calendar: calendar,
      calendar_name: "Test Calendar"
    )
    
    rendered = render partial: 'shared/calendar_today'
    
    assert_includes rendered, "Test Meeting"
    assert_includes rendered, "2:00pm"
    assert_includes rendered, "privacy-sensitive"
  end

  test "calendar today partial shows all day events" do
    calendar = @user.calendars.create!(
      name: "Test Calendar",
      url: "https://example.com/test.ics"
    )
    
    @user.calendar_events.create!(
      uid: "test-all-day-123",
      summary: "All Day Event",
      start_time: Time.current.beginning_of_day,
      end_time: Time.current.end_of_day,
      all_day_event: true,
      calendar: calendar,
      calendar_name: "Test Calendar"
    )
    
    rendered = render partial: 'shared/calendar_today'
    
    assert_includes rendered, "All Day Event"
    assert_includes rendered, "All Day"
  end
end
