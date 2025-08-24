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
    
    # LinkedIn connections stats
    @linkedin_contacts = current_user.contacts.where(source: 'linkedin')
    @linkedin_contacts_count = @linkedin_contacts.count
    @linkedin_contacts_with_companies = @linkedin_contacts.where.not(organization: [nil, '']).count
    @linkedin_contacts_with_job_titles = @linkedin_contacts.where.not(job_title: [nil, '']).count
    @linkedin_last_import = @linkedin_contacts.maximum(:imported_at)
  end
end
