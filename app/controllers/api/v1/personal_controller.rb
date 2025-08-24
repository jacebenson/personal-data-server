class Api::V1::PersonalController < Api::V1::BaseController
  def index
    summary = build_personal_summary
    categories = build_personal_categories

    render_success({
      summary: summary,
      categories: categories,
      last_updated: most_recent_update
    })
  end

  def communications
    emails = current_user.email_messages.order(:date)
    linkedin_messages = current_user.linkedin_messages.order(:date)

    render_success({
      category: "communications",
      email_count: emails.count,
      linkedin_count: linkedin_messages.count,
      total_count: emails.count + linkedin_messages.count,
      date_range: {
        earliest: [ emails.minimum(:date), linkedin_messages.minimum(:date) ].compact.min,
        latest: [ emails.maximum(:date), linkedin_messages.maximum(:date) ].compact.max
      },
      emails: emails.limit(100).map { |email| email_data(email) },
      linkedin_messages: linkedin_messages.limit(100).map { |msg| linkedin_message_data(msg) }
    })
  end

  def calendar_events
    events = current_user.calendar_events.order(:start_time)

    render_success({
      category: "calendar_events",
      count: events.count,
      date_range: date_range_for(events, :start_time),
      items: events.map { |event| calendar_event_data(event) }
    })
  end

  def emails
    emails = current_user.email_messages.order(:date)

    render_success({
      category: "emails",
      count: emails.count,
      date_range: date_range_for(emails, :date),
      items: emails.map { |email| email_data(email) }
    })
  end

  def linkedin_messages
    messages = current_user.linkedin_messages.order(:date)

    render_success({
      category: "linkedin_messages",
      count: messages.count,
      date_range: date_range_for(messages, :date),
      items: messages.map { |msg| linkedin_message_data(msg) }
    })
  end

  private

  def build_personal_summary
    {
      calendar_events_count: current_user.calendar_events.count
    }
  end

  def build_personal_categories
    [
      {
        name: "calendar_events",
        count: current_user.calendar_events.count,
        endpoint: "/api/v1/personal/calendar_events"
      }
    ]
  end

  def most_recent_update
    [
      current_user.calendar_events.maximum(:updated_at)
    ].compact.max
  end

  def date_range_for(collection, date_field)
    {
      earliest: collection.minimum(date_field),
      latest: collection.maximum(date_field)
    }
  end

  def calendar_event_data(event)
    {
      id: event.id,
      title: event.title,
      description_snippet: event.description&.truncate(200),
      start_time: event.start_time,
      end_time: event.end_time,
      location: event.location,
      attendees: event.attendees,
      calendar_name: event.calendar_name,
      event_status: event.event_status,
      organizer: event.organizer,
      created_at: event.created_at
    }
  end
end
