class PersonalController < ApplicationController
  before_action :authenticate_user!

  def index
    # Personal data counts
    @email_messages_count = current_user.email_messages.count
    @linkedin_messages_count = current_user.linkedin_messages.count
    @communications_count = @email_messages_count + @linkedin_messages_count
    @health_records_count = 0
    @contacts_count = current_user.contacts.count
    @calendar_events_count = current_user.calendar_events.count
    @content_items_count = 0
  end
end
