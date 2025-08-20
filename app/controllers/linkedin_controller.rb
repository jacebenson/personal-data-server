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
    
    # Extract participants from from_name and to_name fields
    participants = []
    @conversation_messages.each do |message|
      # Handle pipe-separated names in from_name and to_name
      if message.from_name.present?
        from_names = message.from_name.split('|').map(&:strip)
        participants.concat(from_names)
      end
      
      if message.to_name.present?
        to_names = message.to_name.split('|').flat_map { |names| names.split(',').map(&:strip) }
        participants.concat(to_names)
      end
    end
    
    @participants = participants.uniq.compact.reject(&:blank?)
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
    
    # First, try exact display name match
    exact_matches = current_user.contacts.where(
      "display_name = ? COLLATE NOCASE",
      search_term
    )
    
    if exact_matches.any?
      emails = []
      exact_matches.each do |contact|
        if contact.emails.present?
          contact_emails = contact.emails.split(',').map(&:strip)
          emails.concat(contact_emails)
        end
      end
      return emails.uniq if emails.any?
    end
    
    # For both single and multi-word searches, use word-based matching for better precision
    words = search_term.split(/\s+/)
    
    if words.length > 1
      # For multi-word searches, try different matching strategies
      
      # Strategy 1: Each word matches the beginning of any name field (for cases like "ben f" -> "Benjamin Forrest-Green")
      word_start_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
      word_start_params = words.flat_map { |word| ["#{word}%"] * 4 }
      
      word_start_matches = current_user.contacts.where(word_start_conditions, *word_start_params)
      
      if word_start_matches.any?
        matching_contacts = word_start_matches
      else
        # Strategy 2: Each word appears anywhere in any field (fallback)
        word_conditions = words.map do |word|
          "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
        end.join(" AND ")
        
        word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
        
        matching_contacts = current_user.contacts.where(word_conditions, *word_params)
      end
    else
      # For single word searches, be more precise - try exact field matches first
      single_word = words.first
      
      # Try exact matches in individual fields first
      exact_field_matches = current_user.contacts.where(
        "display_name = ? COLLATE NOCASE OR given_name = ? COLLATE NOCASE OR family_name = ? COLLATE NOCASE",
        single_word, single_word, single_word
      )
      
      if exact_field_matches.any?
        matching_contacts = exact_field_matches
      else
        # Try word boundary patterns and beginning-of-word matches
        boundary_patterns = [
          "#{single_word} ",   # word at start
          " #{single_word} ",  # word surrounded by spaces
          " #{single_word}",   # word at end
          "#{single_word}%"    # word at beginning (new pattern for partial matches)
        ]
        
        boundary_conditions = boundary_patterns.map do |pattern|
          "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
        end.join(" OR ")
        
        boundary_params = boundary_patterns.flat_map { |pattern| [pattern] * 4 }
        
        boundary_matches = current_user.contacts.where(boundary_conditions, *boundary_params)
        
        if boundary_matches.any?
          matching_contacts = boundary_matches
        else
          # Fall back to partial matching if no word boundary matches
          matching_contacts = current_user.contacts.where(
            "display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE",
            "%#{single_word}%", "%#{single_word}%", "%#{single_word}%", "%#{single_word}%"
          )
        end
      end
    end
    
    # Extract emails, but limit to top 3 most relevant contacts to avoid too many results
    emails = []
    matching_contacts.limit(3).each do |contact|
      if contact.emails.present?
        contact_emails = contact.emails.split(',').map(&:strip)
        emails.concat(contact_emails)
      end
    end
    
    emails.uniq
  end

  def fuzzy_contact_names(search_term)
    return [] if search_term.blank?
    
    # First, try exact display name match
    exact_matches = current_user.contacts.where(
      "display_name = ? COLLATE NOCASE",
      search_term
    )
    
    if exact_matches.any?
      return exact_matches.map { |c| c.display_name.presence || "#{c.given_name} #{c.family_name}".strip }
    end
    
    # For both single and multi-word searches, use word-based matching for better precision
    words = search_term.split(/\s+/)
    
    if words.length > 1
      # For multi-word searches, require ALL words to match in the same contact
      word_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
      word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
      
      matching_contacts = current_user.contacts.where(word_conditions, *word_params)
    else
      # For single word searches, be more precise - try exact field matches first
      single_word = words.first
      
      # Try exact matches in individual fields first
      exact_field_matches = current_user.contacts.where(
        "display_name = ? COLLATE NOCASE OR given_name = ? COLLATE NOCASE OR family_name = ? COLLATE NOCASE",
        single_word, single_word, single_word
      )
      
      if exact_field_matches.any?
        matching_contacts = exact_field_matches
      else
        # Fall back to partial matching if no word boundary matches
        matching_contacts = current_user.contacts.where(
          "display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE",
          "%#{single_word}%", "%#{single_word}%", "%#{single_word}%", "%#{single_word}%"
        )
      end
    end
    
    # Limit to top 3 most relevant contacts
    matching_contacts.limit(3).map { |c| c.display_name.presence || "#{c.given_name} #{c.family_name}".strip }
  end

  def debug_contact_search(search_term)
    return {} if search_term.blank?
    
    # Test the exact match first
    exact_matches = current_user.contacts.where(
      "display_name = ? COLLATE NOCASE",
      search_term
    )
    
    # Test full term partial matches
    full_term_matches = current_user.contacts.where(
      "display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE",
      "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
    )
    
    # Test word-by-word matches for multi-word searches
    words = search_term.split(/\s+/)
    if words.length > 1
      # Strategy 1: Word-start matching (each word matches beginning of name fields only)
      word_start_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
      word_start_params = words.flat_map { |word| ["#{word}%"] * 3 }
      
      word_start_matches = current_user.contacts.where(word_start_conditions, *word_start_params)
      
      # Strategy 2: Traditional word matching (each word appears anywhere in all fields including organization)
      word_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
      word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
      
      word_matches = current_user.contacts.where(word_conditions, *word_params)
    else
      # For single words, initialize as empty relation
      word_start_matches = current_user.contacts.none
      word_matches = current_user.contacts.none
    end
    
    {
      exact_matches: exact_matches.limit(5),
      full_term_matches: full_term_matches.limit(5),
      word_start_matches: word_start_matches.limit(5),
      word_matches: word_matches.limit(5),
      search_words: words,
      total_contacts_with_emails: current_user.contacts.where.not(emails: [nil, ""]).count
    }
  end

  def build_from_search_condition(search_term)
    return nil if search_term.blank?
    
    # Try different contact matching strategies in order of preference
    contact_emails = []
    contact_names = []
    matching_strategy = nil
    
    # 1. Exact match (highest priority)
    exact_matches = current_user.contacts.where(
      "display_name = ? COLLATE NOCASE",
      search_term
    )
    
    if exact_matches.any?
      exact_matches.each do |contact|
        if contact.emails.present?
          contact_emails.concat(contact.emails.split(',').map(&:strip))
        end
        # Also collect the contact names
        contact_names << contact.display_name if contact.display_name.present?
        full_name = "#{contact.given_name} #{contact.family_name}".strip
        contact_names << full_name if full_name.present? && full_name != contact.display_name
      end
      matching_strategy = "exact_match" if contact_emails.any? || contact_names.any?
    end
    
    # 2. Word-start matching (for multi-word searches like "ben f")
    if contact_emails.empty? && contact_names.empty?
      words = search_term.split(/\s+/)
      if words.length > 1
        # For name searches, only match against name fields (not organization) to avoid false positives
        word_start_conditions = words.map do |word|
          "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE)"
        end.join(" AND ")
        
        word_start_params = words.flat_map { |word| ["#{word}%"] * 3 }
        
        word_start_matches = current_user.contacts.where(word_start_conditions, *word_start_params)
        
        if word_start_matches.any?
          word_start_matches.each do |contact|
            if contact.emails.present?
              contact_emails.concat(contact.emails.split(',').map(&:strip))
            end
            # Also collect the contact names
            contact_names << contact.display_name if contact.display_name.present?
            full_name = "#{contact.given_name} #{contact.family_name}".strip
            contact_names << full_name if full_name.present? && full_name != contact.display_name
          end
          matching_strategy = "word_start_match" if contact_emails.any? || contact_names.any?
        end
      end
    end
    
    # 3. Word-anywhere matching (each word appears somewhere)
    if contact_emails.empty? && contact_names.empty?
      words = search_term.split(/\s+/)
      if words.length > 1
        word_conditions = words.map do |word|
          "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
        end.join(" AND ")
        
        word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
        
        word_matches = current_user.contacts.where(word_conditions, *word_params)
        
        if word_matches.any?
          word_matches.each do |contact|
            if contact.emails.present?
              contact_emails.concat(contact.emails.split(',').map(&:strip))
            end
            # Also collect the contact names
            contact_names << contact.display_name if contact.display_name.present?
            full_name = "#{contact.given_name} #{contact.family_name}".strip
            contact_names << full_name if full_name.present? && full_name != contact.display_name
          end
          matching_strategy = "word_anywhere_match" if contact_emails.any? || contact_names.any?
        end
      end
    end
    
    # 4. Partial matching (fallback)
    if contact_emails.empty? && contact_names.empty?
      partial_matches = current_user.contacts.where(
        "display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE",
        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
      )
      
      if partial_matches.any?
        partial_matches.limit(3).each do |contact|
          if contact.emails.present?
            contact_emails.concat(contact.emails.split(',').map(&:strip))
          end
          # Also collect the contact names
          contact_names << contact.display_name if contact.display_name.present?
          full_name = "#{contact.given_name} #{contact.family_name}".strip
          contact_names << full_name if full_name.present? && full_name != contact.display_name
        end
        matching_strategy = "partial_match" if contact_emails.any? || contact_names.any?
      end
    end
    
    # Build LinkedIn message search condition
    if contact_emails.any? || contact_names.any?
      # Clean and deduplicate emails and names
      contact_emails = contact_emails.uniq.reject(&:blank?)
      contact_names = contact_names.uniq.reject(&:blank?)
      
      search_conditions = []
      search_params = []
      
      # Add email-based search conditions
      if contact_emails.any?
        email_conditions = contact_emails.map { "from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE" }.join(" OR ")
        email_params = contact_emails.flat_map { |email| ["%#{email}%", "%#{email}%"] }
        search_conditions << "(#{email_conditions})"
        search_params.concat(email_params)
      end
      
      # Add name-based search conditions
      if contact_names.any?
        name_conditions = contact_names.map { "from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE" }.join(" OR ")
        name_params = contact_names.flat_map { |name| ["%#{name}%", "%#{name}%"] }
        search_conditions << "(#{name_conditions})"
        search_params.concat(name_params)
      end
      
      # Also include direct search term as fallback
      direct_conditions = "from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE"
      direct_params = ["%#{search_term}%", "%#{search_term}%"]
      search_conditions << "(#{direct_conditions})"
      search_params.concat(direct_params)
      
      # Combine all strategies with OR
      combined_conditions = search_conditions.join(" OR ")
      
      # Store debug info about the strategy used
      @contact_matching_strategy = matching_strategy
      @matched_contact_emails = contact_emails
      @matched_contact_names = contact_names
      
      return [combined_conditions] + search_params
    else
      # No contacts found, fall back to direct name search only
      @contact_matching_strategy = "direct_name_only"
      @matched_contact_emails = []
      @matched_contact_names = []
      
      conditions = ["from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE", "%#{search_term}%", "%#{search_term}%"]
      return conditions
    end
  end
end
