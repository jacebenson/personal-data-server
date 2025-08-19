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
      category: 'communications',
      email_count: emails.count,
      linkedin_count: linkedin_messages.count,
      total_count: emails.count + linkedin_messages.count,
      date_range: {
        earliest: [emails.minimum(:date), linkedin_messages.minimum(:date)].compact.min,
        latest: [emails.maximum(:date), linkedin_messages.maximum(:date)].compact.max
      },
      emails: emails.limit(100).map { |email| email_data(email) },
      linkedin_messages: linkedin_messages.limit(100).map { |msg| linkedin_message_data(msg) }
    })
  end

  def contacts
    contacts = current_user.contacts.order(:name)

    render_success({
      category: 'contacts',
      count: contacts.count,
      items: contacts.map { |contact| contact_data(contact) }
    })
  end

  def calendar_events
    events = current_user.calendar_events.order(:start_time)

    render_success({
      category: 'calendar_events',
      count: events.count,
      date_range: date_range_for(events, :start_time),
      items: events.map { |event| calendar_event_data(event) }
    })
  end

  def emails
    emails = current_user.email_messages.order(:date)

    render_success({
      category: 'emails',
      count: emails.count,
      date_range: date_range_for(emails, :date),
      items: emails.map { |email| email_data(email) }
    })
  end

  def linkedin_messages
    messages = current_user.linkedin_messages.order(:date)

    render_success({
      category: 'linkedin_messages',
      count: messages.count,
      date_range: date_range_for(messages, :date),
      items: messages.map { |msg| linkedin_message_data(msg) }
    })
  end

  private

  def build_personal_summary
    {
      email_messages_count: current_user.email_messages.count,
      linkedin_messages_count: current_user.linkedin_messages.count,
      contacts_count: current_user.contacts.count,
      calendar_events_count: current_user.calendar_events.count,
      total_communications: current_user.email_messages.count + current_user.linkedin_messages.count
    }
  end

  def build_personal_categories
    [
      {
        name: 'communications',
        email_count: current_user.email_messages.count,
        linkedin_count: current_user.linkedin_messages.count,
        total_count: current_user.email_messages.count + current_user.linkedin_messages.count,
        endpoint: '/api/v1/personal/communications'
      },
      {
        name: 'contacts',
        count: current_user.contacts.count,
        endpoint: '/api/v1/personal/contacts'
      },
      {
        name: 'calendar_events',
        count: current_user.calendar_events.count,
        endpoint: '/api/v1/personal/calendar_events'
      },
      {
        name: 'emails',
        count: current_user.email_messages.count,
        endpoint: '/api/v1/personal/emails'
      },
      {
        name: 'linkedin_messages',
        count: current_user.linkedin_messages.count,
        endpoint: '/api/v1/personal/linkedin_messages'
      }
    ]
  end

  def most_recent_update
    [
      current_user.email_messages.maximum(:updated_at),
      current_user.linkedin_messages.maximum(:updated_at),
      current_user.contacts.maximum(:updated_at),
      current_user.calendar_events.maximum(:updated_at)
    ].compact.max
  end

  def date_range_for(collection, date_field)
    {
      earliest: collection.minimum(date_field),
      latest: collection.maximum(date_field)
    }
  end

  def email_data(email)
    {
      id: email.id,
      date: email.date,
      from: email.from,
      to: email.to,
      cc: email.cc,
      bcc: email.bcc,
      subject: email.subject,
      body_snippet: email.body&.truncate(200),
      message_id: email.message_id,
      in_reply_to: email.in_reply_to,
      references: email.references,
      labels: email.labels,
      thread_id: email.thread_id
    }
  end

  def linkedin_message_data(message)
    {
      id: message.id,
      date: message.date,
      from: message.from,
      to: message.to,
      content_snippet: message.content&.truncate(200),
      conversation_id: message.conversation_id,
      message_type: message.message_type
    }
  end

  def contact_data(contact)
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone: contact.phone,
      company: contact.company,
      title: contact.title,
      source: contact.source,
      notes: contact.notes,
      linkedin_url: contact.linkedin_url,
      tags: contact.tags
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
