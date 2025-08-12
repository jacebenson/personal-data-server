class Api::V1::CommunicationsController < Api::V1::BaseController
  def index
    search_query = params[:q]&.downcase
    limit = (params[:limit] || 50).to_i
    
    render_success({
      emails: search_emails(search_query).limit(limit),
      linkedin: search_linkedin(search_query).limit(limit)
    })
  end

  private

  def search_emails(query)
    emails = current_user.email_messages.order(received_date: :desc)
    if query.present?
      emails = emails.where("LOWER(subject) LIKE ? OR LOWER(sender_email) LIKE ? OR LOWER(content) LIKE ?", 
                           "%#{query}%", "%#{query}%", "%#{query}%")
    end
    
    emails.map do |email|
      {
        date: email.received_date,
        from: email.sender_email,
        from_name: email.sender_name,
        subject: email.subject,
        content_snippet: email.content&.truncate(200),
        folder: email.folder
      }
    end
  end

  def search_linkedin(query)
    messages = current_user.linkedin_messages.order(sent_at: :desc)
    if query.present?
      messages = messages.where("LOWER(subject) LIKE ? OR LOWER(from_name) LIKE ? OR LOWER(content) LIKE ?", 
                               "%#{query}%", "%#{query}%", "%#{query}%")
    end
    
    messages.map do |message|
      {
        date: message.sent_at,
        from: message.from_name,
        to: message.to_name,
        subject: message.subject,
        content_snippet: message.content&.truncate(200),
        conversation_title: message.conversation_title
      }
    end
  end
end
