class LinkedinController < ApplicationController
  before_action :authenticate_user!

  def index
    # Main LinkedIn page - shows upload form and statistics
    @total_messages = current_user.linkedin_messages.count
    @total_conversations = current_user.linkedin_messages.distinct.count(:conversation_id)
    @recent_messages = current_user.linkedin_messages.recent.limit(5)
    @date_range = {
      earliest: current_user.linkedin_messages.minimum(:sent_at),
      latest: current_user.linkedin_messages.maximum(:sent_at)
    }
  end

  def messages
    # Show all LinkedIn messages with search and pagination
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Search parameters
    @search_subject = params[:search_subject]
    @search_from = params[:search_from]
    @search_date_from = params[:search_date_from]
    @search_date_to = params[:search_date_to]

    # Build the scope
    messages_scope = current_user.linkedin_messages
    messages_scope = messages_scope.by_folder(params[:folder]) if params[:folder].present?
    
    # Apply search filters
    if @search_subject.present?
      messages_scope = messages_scope.where(
        "subject LIKE ? COLLATE NOCASE OR content LIKE ? COLLATE NOCASE", 
        "%#{@search_subject}%", "%#{@search_subject}%"
      )
    end
    
    if @search_from.present?
      from_conditions = build_from_search_condition(@search_from)
      messages_scope = messages_scope.where(from_conditions) if from_conditions
    end
    
    # Date range search
    if @search_date_from.present? && @search_date_to.present?
      begin
        start_date = Date.parse(@search_date_from)
        end_date = Date.parse(@search_date_to)
        messages_scope = messages_scope.by_date_range(start_date.beginning_of_day, end_date.end_of_day)
      rescue ArgumentError
        # Invalid date format, ignore date filter
      end
    elsif @search_date_from.present?
      begin
        start_date = Date.parse(@search_date_from)
        messages_scope = messages_scope.where("sent_at >= ?", start_date.beginning_of_day)
      rescue ArgumentError
        # Invalid date format, ignore date filter
      end
    elsif @search_date_to.present?
      begin
        end_date = Date.parse(@search_date_to)
        messages_scope = messages_scope.where("sent_at <= ?", end_date.end_of_day)
      rescue ArgumentError
        # Invalid date format, ignore date filter
      end
    end

    @linkedin_messages = messages_scope.recent.limit(per_page).offset(offset)
    @total_count = messages_scope.count

    # Pagination variables
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filtered_folder = params[:folder]

    # For preserving search params in pagination and folder links
    @search_params = {
      search_subject: @search_subject,
      search_from: @search_from,
      search_date_from: @search_date_from,
      search_date_to: @search_date_to
    }.compact

    # Statistics for folders and participants
    folder_scope = current_user.linkedin_messages
    if @search_subject.present?
      folder_scope = folder_scope.where(
        "subject LIKE ? COLLATE NOCASE OR content LIKE ? COLLATE NOCASE", 
        "%#{@search_subject}%", "%#{@search_subject}%"
      )
    end
    
    if @search_from.present?
      from_conditions = build_from_search_condition(@search_from)
      folder_scope = folder_scope.where(from_conditions) if from_conditions
    end
    
    # Apply date filters for folder counts
    if @search_date_from.present? && @search_date_to.present?
      begin
        start_date = Date.parse(@search_date_from)
        end_date = Date.parse(@search_date_to)
        folder_scope = folder_scope.by_date_range(start_date.beginning_of_day, end_date.end_of_day)
      rescue ArgumentError
      end
    elsif @search_date_from.present?
      begin
        start_date = Date.parse(@search_date_from)
        folder_scope = folder_scope.where("sent_at >= ?", start_date.beginning_of_day)
      rescue ArgumentError
      end
    elsif @search_date_to.present?
      begin
        end_date = Date.parse(@search_date_to)
        folder_scope = folder_scope.where("sent_at <= ?", end_date.end_of_day)
      rescue ArgumentError
      end
    end
    
    @folders = folder_scope.group(:folder).count.sort_by { |folder, count| -count }
    @top_participants = current_user.linkedin_messages
                                   .group(:from_name)
                                   .order(Arel.sql("COUNT(*) DESC"))
                                   .limit(10)
                                   .count
    @date_range = {
      earliest: current_user.linkedin_messages.minimum(:sent_at),
      latest: current_user.linkedin_messages.maximum(:sent_at)
    }

    # Debug information for search
    if @search_from.present?
      @debug_contact_emails = fuzzy_contact_emails(@search_from)
      @debug_contact_names = fuzzy_contact_names(@search_from)
      @debug_search_conditions = build_from_search_condition(@search_from)
      @debug_total_contacts = current_user.contacts.count
      @debug_detailed = debug_contact_search(@search_from)
    end
  end

  def show
    # Show individual LinkedIn message
    @linkedin_message = current_user.linkedin_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to messages_linkedin_index_path, alert: "LinkedIn message not found."
  end

  def conversations
    # Show conversations grouped view
    @conversations = current_user.linkedin_messages
                                .group(:conversation_id, :conversation_title)
                                .order('MAX(sent_at) DESC')
                                .limit(50)
                                .pluck(
                                  :conversation_id, 
                                  :conversation_title, 
                                  'COUNT(*) as message_count',
                                  'MAX(sent_at) as last_message_at'
                                )
  end

  def conversation
    # Show messages in a specific conversation
    @conversation_id = params[:conversation_id]
    @conversation_messages = current_user.linkedin_messages
                                        .where(conversation_id: @conversation_id)
                                        .order(:sent_at)
    
    @conversation_title = @conversation_messages.first&.conversation_title || "Unknown Conversation"
    @participants = @conversation_messages.pluck(:from_name, :to_name).flatten.uniq.compact
  end

  def upload
    # Process uploaded LinkedIn messages CSV
    if params[:file].present?
      begin
        result = LinkedinMessagesProcessor.new(params[:file], current_user).process

        if result[:errors].any?
          error_message = "Errors occurred during import: #{result[:errors].join(', ')}"
          redirect_to linkedin_index_path, alert: error_message
        else
          message = "Successfully imported #{result[:imported]} LinkedIn messages."
          if result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end
          redirect_to linkedin_index_path, notice: message
        end
      rescue => e
        redirect_to linkedin_index_path, alert: "Error processing LinkedIn messages file: #{e.message}"
      end
    else
      redirect_to linkedin_index_path, alert: "Please select a LinkedIn messages CSV file to upload."
    end
  end

  def clear
    # Clear all LinkedIn messages for the current user
    count = current_user.linkedin_messages.count
    current_user.linkedin_messages.destroy_all
    redirect_to linkedin_path, notice: "Successfully deleted #{count} LinkedIn messages."
  end

  private

  def fuzzy_contact_emails(search_term)
    return [] if search_term.blank?
    
    # Use the contacts to find email addresses
    contacts = current_user.contacts.where(
      "name LIKE ? COLLATE NOCASE OR first_name LIKE ? COLLATE NOCASE OR last_name LIKE ? COLLATE NOCASE",
      "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
    )
    
    emails = []
    contacts.each do |contact|
      contact.emails&.each { |email| emails << email }
    end
    emails.uniq
  end

  def fuzzy_contact_names(search_term)
    return [] if search_term.blank?
    
    current_user.contacts.where(
      "name LIKE ? COLLATE NOCASE OR first_name LIKE ? COLLATE NOCASE OR last_name LIKE ? COLLATE NOCASE",
      "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
    ).pluck(:name, :first_name, :last_name).flatten.compact.uniq
  end

  def debug_contact_search(search_term)
    return {} if search_term.blank?
    
    # Exact matches (case insensitive)
    exact_matches = current_user.contacts.where(
      "LOWER(name) = ? OR LOWER(first_name) = ? OR LOWER(last_name) = ?", 
      search_term.downcase, search_term.downcase, search_term.downcase
    )
    
    # Full term matches (partial)
    full_term_matches = current_user.contacts.where(
      "name LIKE ? COLLATE NOCASE OR first_name LIKE ? COLLATE NOCASE OR last_name LIKE ? COLLATE NOCASE",
      "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
    )
    
    # Word-by-word matches
    words = search_term.split
    if words.length > 1
      word_conditions = words.map { 
        "(name LIKE ? COLLATE NOCASE OR first_name LIKE ? COLLATE NOCASE OR last_name LIKE ? COLLATE NOCASE OR emails LIKE ? COLLATE NOCASE)" 
      }.join(" AND ")
      
      word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
      
      word_matches = current_user.contacts.where(word_conditions, *word_params)
    else
      # For single words, initialize as empty relation
      word_matches = current_user.contacts.none
    end
    
    {
      exact_matches: exact_matches.limit(5),
      full_term_matches: full_term_matches.limit(5),
      word_matches: word_matches.limit(5),
      search_words: words,
      total_contacts_with_emails: current_user.contacts.where.not(emails: [nil, ""]).count
    }
  end

  def build_from_search_condition(search_term)
    return nil if search_term.blank?
    
    # Get emails from fuzzy contact search
    contact_emails = fuzzy_contact_emails(search_term)
    
    # For LinkedIn, search participants (from_name, to_name) and also include direct term search
    conditions = ["from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE", "%#{search_term}%", "%#{search_term}%"]
    
    # Add email-based search if we found matching contacts
    if contact_emails.any?
      email_conditions = contact_emails.map { "from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE" }.join(" OR ")
      email_params = contact_emails.flat_map { |email| ["%#{email}%", "%#{email}%"] }
      conditions[0] += " OR #{email_conditions}"
      conditions.concat(email_params)
    end
    
    conditions
  end
end
