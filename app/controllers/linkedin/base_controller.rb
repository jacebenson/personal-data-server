class Linkedin::BaseController < ApplicationController
  before_action :authenticate_user!

  protected

  # Shared contact search functionality used across LinkedIn controllers
  def fuzzy_contact_emails(search_term)
    return [] if search_term.blank?
    
    # Search LinkedIn messages for contacts matching the search term
    normalized_search = search_term.downcase.strip
    
    # Get unique contacts from LinkedIn messages
    contacts = current_user.linkedin_messages
                          .where("LOWER(from_name) LIKE ? OR LOWER(to_name) LIKE ?", 
                                "%#{normalized_search}%", "%#{normalized_search}%")
                          .pluck(:from_name, :to_name)
                          .flatten
                          .compact
                          .uniq
                          .select { |name| name.downcase.include?(normalized_search) }
    
    # Return contact names as emails aren't available in LinkedIn messages
    contacts
  end

  def fuzzy_search(search_term)
    # Delegate to fuzzy_contact_emails for consistency
    fuzzy_contact_emails(search_term)
  end

  def search_contact_names(search_term)
    return [] if search_term.blank?
    
    normalized_search = search_term.downcase.strip
    
    # Get unique contact names from LinkedIn messages
    current_user.linkedin_messages
                .where("LOWER(from_name) LIKE ? OR LOWER(to_name) LIKE ?", 
                      "%#{normalized_search}%", "%#{normalized_search}%")
                .pluck(:from_name, :to_name)
                .flatten
                .compact
                .uniq
                .select { |name| name.downcase.include?(normalized_search) }
                .sort
  end

  def participant_counts_for_conversations(conversations)
    conversation_ids = conversations.pluck(:id)
    
    LinkedinMessage.joins(:user)
                   .where(user: current_user, linkedin_conversation_id: conversation_ids)
                   .group(:linkedin_conversation_id, :participant_names)
                   .distinct
                   .group(:linkedin_conversation_id)
                   .count
  end

  def messages_by_conversation(conversations)
    conversation_ids = conversations.pluck(:id)
    
    LinkedinMessage.joins(:user)
                   .where(user: current_user, linkedin_conversation_id: conversation_ids)
                   .group(:linkedin_conversation_id)
                   .count
  end

  def latest_messages_for_conversations(conversations)
    conversation_ids = conversations.pluck(:id)
    
    # Get the latest message for each conversation
    latest_message_ids = LinkedinMessage.joins(:user)
                                        .where(user: current_user, linkedin_conversation_id: conversation_ids)
                                        .group(:linkedin_conversation_id)
                                        .maximum(:id)
    
    # Fetch the actual messages
    LinkedinMessage.where(id: latest_message_ids.values)
                   .index_by(&:linkedin_conversation_id)
  end

  def search_conversations_by_participants(search_term)
    return LinkedinConversation.none if search_term.blank?
    
    # Get conversation IDs that have messages with matching participant names
    conversation_ids = LinkedinMessage.joins(:user)
                                      .where(user: current_user)
                                      .where("LOWER(participant_names) LIKE ?", "%#{search_term.downcase}%")
                                      .distinct
                                      .pluck(:linkedin_conversation_id)
    
    LinkedinConversation.joins(:user).where(user: current_user, id: conversation_ids)
  end

  def search_messages_by_content(search_term)
    return LinkedinMessage.none if search_term.blank?
    
    LinkedinMessage.joins(:user)
                   .where(user: current_user)
                   .where("LOWER(content) LIKE ?", "%#{search_term.downcase}%")
  end

  def search_messages_by_sender(search_term)
    return LinkedinMessage.none if search_term.blank?
    
    LinkedinMessage.joins(:user)
                   .where(user: current_user)
                   .where("LOWER(sender_name) LIKE ?", "%#{search_term.downcase}%")
  end

  def conversation_participants_summary(conversation)
    return "No participants" unless conversation
    
    # Get unique participant names from messages in this conversation
    participants = LinkedinMessage.joins(:user)
                                  .where(user: current_user, linkedin_conversation_id: conversation.id)
                                  .distinct
                                  .pluck(:participant_names)
                                  .compact
                                  .flat_map { |names| names.split(',').map(&:strip) }
                                  .uniq
                                  .reject(&:blank?)
    
    if participants.length <= 3
      participants.join(', ')
    else
      "#{participants.first(3).join(', ')} and #{participants.length - 3} others"
    end
  end

  def format_message_time(timestamp)
    return "Unknown time" unless timestamp
    
    if timestamp.is_a?(String)
      begin
        timestamp = Time.parse(timestamp)
      rescue
        return "Invalid time"
      end
    end
    
    now = Time.current
    diff = now - timestamp
    
    case diff
    when 0..1.hour
      "#{(diff / 1.minute).round} minutes ago"
    when 1.hour..1.day
      "#{(diff / 1.hour).round} hours ago"
    when 1.day..1.week
      "#{(diff / 1.day).round} days ago"
    when 1.week..1.month
      "#{(diff / 1.week).round} weeks ago"
    else
      timestamp.strftime("%b %d, %Y")
    end
  end

  def safe_json_parse(json_string, default = {})
    return default if json_string.blank?
    
    begin
      JSON.parse(json_string)
    rescue JSON::ParserError
      default
    end
  end

  def format_participant_names(names_string)
    return "Unknown" if names_string.blank?
    
    names = names_string.split(',').map(&:strip).reject(&:blank?)
    
    case names.length
    when 0
      "Unknown"
    when 1
      names.first
    when 2
      names.join(' and ')
    else
      "#{names.first(2).join(', ')} and #{names.length - 2} others"
    end
  end

  def conversation_message_count(conversation_id)
    LinkedinMessage.joins(:user)
                   .where(user: current_user, linkedin_conversation_id: conversation_id)
                   .count
  end

  def conversation_date_range(conversation_id)
    messages = LinkedinMessage.joins(:user)
                              .where(user: current_user, linkedin_conversation_id: conversation_id)
                              .order(:sent_at)
    
    return "No messages" if messages.empty?
    
    first_message = messages.first
    last_message = messages.last
    
    return format_message_time(first_message.sent_at) if first_message == last_message
    
    "#{format_message_time(first_message.sent_at)} - #{format_message_time(last_message.sent_at)}"
  end

  def filter_conversations_by_date_range(conversations, start_date, end_date)
    return conversations unless start_date.present? || end_date.present?
    
    conversation_ids = conversations.pluck(:id)
    
    message_query = LinkedinMessage.joins(:user)
                                   .where(user: current_user, linkedin_conversation_id: conversation_ids)
    
    message_query = message_query.where("sent_at >= ?", start_date) if start_date.present?
    message_query = message_query.where("sent_at <= ?", end_date) if end_date.present?
    
    filtered_conversation_ids = message_query.distinct.pluck(:linkedin_conversation_id)
    
    conversations.where(id: filtered_conversation_ids)
  end

  def conversation_has_attachments?(conversation_id)
    LinkedinMessage.joins(:user)
                   .where(user: current_user, linkedin_conversation_id: conversation_id)
                   .where.not(attachments: [nil, "", "[]"])
                   .exists?
  end

  def extract_attachments_from_message(message)
    return [] unless message.attachments.present?
    
    attachments = safe_json_parse(message.attachments, [])
    return [] unless attachments.is_a?(Array)
    
    attachments.map do |attachment|
      {
        name: attachment['name'] || 'Unknown file',
        url: attachment['url'],
        type: attachment['type'] || 'unknown',
        size: attachment['size']
      }
    end
  end

  def group_messages_by_date(messages)
    messages.group_by { |message| message.sent_at&.to_date || Date.current }
            .sort_by { |date, _| date }
  end

  def message_search_params
    params.permit(:q, :sender, :content, :conversation_id, :start_date, :end_date, :has_attachments)
  end

  def conversation_search_params
    params.permit(:q, :participants, :start_date, :end_date, :has_attachments)
  end

  def pagination_params
    {
      page: [params[:page].to_i, 1].max,
      per_page: [params[:per_page].to_i, 50].max
    }
  end

  def apply_pagination(query, page: 1, per_page: 50)
    offset = (page - 1) * per_page
    query.offset(offset).limit(per_page)
  end

  def calculate_total_pages(total_count, per_page)
    (total_count.to_f / per_page).ceil
  end

  def set_pagination_info(query, page, per_page)
    total_count = query.count
    total_pages = calculate_total_pages(total_count, per_page)
    
    {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_previous: page > 1,
      has_next: page < total_pages
    }
  end
end
