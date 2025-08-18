# frozen_string_literal: true

# MCP Communications Controller - handles person contact and mention searches
class Api::V1::Mcp::CommunicationsController < Api::V1::Mcp::BaseController
  
  # Find contact information and recent interactions for a person
  # POST /api/v1/mcp/find_person_contact
  def find_person_contact
    return unless validate_required_params(:name)
    
    name = @sanitized_params[:query] || params[:name]
    include_history = @sanitized_params[:include_history] || false
    
    contact_info = find_contact_by_name(name)
    recent_interactions = include_history ? find_recent_interactions(name) : []
    
    response_data = {
      person_name: name,
      contact_info: contact_info,
      recent_interactions: recent_interactions,
      interaction_count: recent_interactions.length
    }
    
    context_message = build_contact_context_message(name, contact_info, recent_interactions)
    suggested_actions = ['get_conversation_history', 'find_recent_mentions']
    
    render_success(response_data, context_message, suggested_actions)
  end
  
  # Find recent mentions of terms in communications
  # POST /api/v1/mcp/find_recent_mentions
  def find_recent_mentions
    return unless validate_required_params(:term)
    
    term = @sanitized_params[:query] || params[:term]
    timeframe = @sanitized_params[:parsed_timeframe] || TimeExpressionParser.parse('recent')
    sources = @sanitized_params[:sources] || %w[email linkedin messages]
    group_by_person = params[:group_by] == 'person'
    
    mentions = find_mentions(term, timeframe, sources, @sanitized_params[:limit])
    
    response_data = if group_by_person
                      group_mentions_by_person(mentions, term)
                    else
                      {
                        term: term,
                        timeframe: @sanitized_params[:timeframe] || 'recent',
                        sources: sources,
                        mentions: mentions,
                        total_mentions: mentions.length
                      }
                    end
    
    context_message = build_mentions_context_message(term, mentions, group_by_person)
    suggested_actions = ['find_person_contact', 'get_conversation_history']
    
    render_success(response_data, context_message, suggested_actions)
  end
  
  # Get conversation history with a specific person
  # POST /api/v1/mcp/get_conversation_history
  def get_conversation_history
    return unless validate_required_params(:person_name)
    
    person_name = params[:person_name]
    timeframe = @sanitized_params[:parsed_timeframe]
    limit = @sanitized_params[:limit]
    include_context = @sanitized_params[:include_context] || false
    
    conversations = find_conversation_history(person_name, timeframe, limit, include_context)
    
    response_data = {
      person_name: person_name,
      timeframe: @sanitized_params[:timeframe],
      conversations: conversations,
      total_conversations: conversations.length,
      include_context: include_context
    }
    
    context_message = "Found #{conversations.length} conversations with #{person_name}"
    context_message += " in #{describe_timeframe(@sanitized_params[:timeframe], timeframe)}" if timeframe
    
    suggested_actions = ['find_person_contact', 'find_recent_mentions']
    
    render_success(response_data, context_message, suggested_actions)
  end

  private

  def find_contact_by_name(name)
    contact_sources = []
    
    # Search in Communications for email contacts
    if defined?(Communication)
      email_contacts = current_user.communications
                                  .where("sender ILIKE ?", "%#{name}%")
                                  .group(:sender)
                                  .order('MAX(created_at) DESC')
                                  .limit(5)
                                  .pluck(:sender)
                                  .map { |sender| { source: 'email', contact: sender } }
      contact_sources.concat(email_contacts)
    end
    
    # Search in LinkedIn messages
    if defined?(LinkedinMessage)
      linkedin_contacts = current_user.linkedin_messages
                                     .where("sender ILIKE ?", "%#{name}%")
                                     .group(:sender)
                                     .order('MAX(sent_at) DESC')
                                     .limit(5)
                                     .pluck(:sender)
                                     .map { |sender| { source: 'linkedin', contact: sender } }
      contact_sources.concat(linkedin_contacts)
    end
    
    # Search in contacts/VCards if available
    if defined?(Contact)
      vcard_contacts = current_user.contacts
                                  .where("name ILIKE ? OR email ILIKE ?", "%#{name}%", "%#{name}%")
                                  .limit(5)
                                  .map do |contact|
        {
          source: 'contacts',
          name: contact.name,
          email: contact.email,
          phone: contact.phone
        }
      end
      contact_sources.concat(vcard_contacts)
    end
    
    # Remove duplicates and return most recent
    contact_sources.uniq { |c| c[:contact] || c[:email] }.first(10)
  end

  def find_recent_interactions(name)
    interactions = []
    
    # Email interactions
    if defined?(Communication)
      email_interactions = current_user.communications
                                      .where("sender ILIKE ?", "%#{name}%")
                                      .order(created_at: :desc)
                                      .limit(10)
                                      .map do |comm|
        {
          type: 'email',
          date: comm.created_at,
          subject: comm.subject,
          sender: comm.sender,
          snippet: comm.content&.truncate(200)
        }
      end
      interactions.concat(email_interactions)
    end
    
    # LinkedIn interactions
    if defined?(LinkedinMessage)
      linkedin_interactions = current_user.linkedin_messages
                                         .where("sender ILIKE ?", "%#{name}%")
                                         .order(sent_at: :desc)
                                         .limit(10)
                                         .map do |msg|
        {
          type: 'linkedin',
          date: msg.sent_at,
          sender: msg.sender,
          snippet: msg.content&.truncate(200)
        }
      end
      interactions.concat(linkedin_interactions)
    end
    
    # Sort all interactions by date and return most recent
    interactions.sort_by { |i| i[:date] }.reverse.first(20)
  end

  def find_mentions(term, timeframe, sources, limit)
    mentions = []
    
    # Search emails
    if sources.include?('email') && defined?(Communication)
      email_scope = current_user.communications
                               .where("subject ILIKE ? OR content ILIKE ?", "%#{term}%", "%#{term}%")
      email_scope = email_scope.where(created_at: timeframe) if timeframe
      
      email_mentions = email_scope.order(created_at: :desc)
                                 .limit(limit / sources.length)
                                 .map do |comm|
        {
          type: 'email',
          date: comm.created_at,
          sender: comm.sender,
          subject: comm.subject,
          snippet: extract_mention_snippet(comm.content || comm.subject, term)
        }
      end
      mentions.concat(email_mentions)
    end
    
    # Search LinkedIn messages
    if sources.include?('linkedin') && defined?(LinkedinMessage)
      linkedin_scope = current_user.linkedin_messages
                                  .where("content ILIKE ?", "%#{term}%")
      linkedin_scope = linkedin_scope.where(sent_at: timeframe) if timeframe
      
      linkedin_mentions = linkedin_scope.order(sent_at: :desc)
                                       .limit(limit / sources.length)
                                       .map do |msg|
        {
          type: 'linkedin',
          date: msg.sent_at,
          sender: msg.sender,
          snippet: extract_mention_snippet(msg.content, term)
        }
      end
      mentions.concat(linkedin_mentions)
    end
    
    # Sort by date and return most recent
    mentions.sort_by { |m| m[:date] }.reverse.first(limit)
  end

  def find_conversation_history(person_name, timeframe, limit, include_context)
    conversations = []
    
    # Get email conversations
    if defined?(Communication)
      email_scope = current_user.communications
                               .where("sender ILIKE ?", "%#{person_name}%")
      email_scope = email_scope.where(created_at: timeframe) if timeframe
      
      email_conversations = email_scope.order(created_at: :desc)
                                      .limit(limit / 2)
                                      .map do |comm|
        conversation = {
          type: 'email',
          date: comm.created_at,
          sender: comm.sender,
          subject: comm.subject
        }
        
        if include_context
          conversation[:content] = comm.content&.truncate(500)
        else
          conversation[:snippet] = comm.content&.truncate(200)
        end
        
        conversation
      end
      conversations.concat(email_conversations)
    end
    
    # Get LinkedIn conversations
    if defined?(LinkedinMessage)
      linkedin_scope = current_user.linkedin_messages
                                  .where("sender ILIKE ?", "%#{person_name}%")
      linkedin_scope = linkedin_scope.where(sent_at: timeframe) if timeframe
      
      linkedin_conversations = linkedin_scope.order(sent_at: :desc)
                                            .limit(limit / 2)
                                            .map do |msg|
        conversation = {
          type: 'linkedin',
          date: msg.sent_at,
          sender: msg.sender
        }
        
        if include_context
          conversation[:content] = msg.content&.truncate(500)
        else
          conversation[:snippet] = msg.content&.truncate(200)
        end
        
        conversation
      end
      conversations.concat(linkedin_conversations)
    end
    
    # Sort by date and return most recent
    conversations.sort_by { |c| c[:date] }.reverse.first(limit)
  end

  def extract_mention_snippet(content, term)
    return '' if content.blank?
    
    # Find the position of the term (case insensitive)
    content_lower = content.downcase
    term_lower = term.downcase
    position = content_lower.index(term_lower)
    
    return content.truncate(200) unless position
    
    # Extract context around the term
    start_pos = [0, position - 100].max
    end_pos = [content.length, position + term.length + 100].min
    
    snippet = content[start_pos...end_pos]
    snippet = "...#{snippet}" if start_pos > 0
    snippet = "#{snippet}..." if end_pos < content.length
    
    snippet
  end

  def group_mentions_by_person(mentions, term)
    grouped = mentions.group_by { |m| m[:sender] }
    
    {
      term: term,
      grouped_by: 'person',
      people: grouped.map do |person, person_mentions|
        {
          person_name: person,
          mention_count: person_mentions.length,
          recent_mentions: person_mentions.first(5),
          last_mention_date: person_mentions.first[:date]
        }
      end.sort_by { |p| p[:last_mention_date] }.reverse
    }
  end

  def build_contact_context_message(name, contact_info, recent_interactions)
    if contact_info.empty?
      "No contact information found for '#{name}'"
    else
      message = "Found #{contact_info.length} contact sources for '#{name}'"
      message += " with #{recent_interactions.length} recent interactions" if recent_interactions.any?
      message
    end
  end

  def build_mentions_context_message(term, mentions, group_by_person)
    if mentions.empty?
      "No recent mentions found for '#{term}'"
    elsif group_by_person
      unique_people = mentions.map { |m| m[:sender] }.uniq.length
      "Found #{mentions.length} mentions of '#{term}' from #{unique_people} people"
    else
      "Found #{mentions.length} recent mentions of '#{term}'"
    end
  end
end
