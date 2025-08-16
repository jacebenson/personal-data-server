class CommunicationsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Combined communication upload page for MBOX, LinkedIn messages, and Discord
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
          contact.email_list.each { |email| emails << email }
        end
      end
      return emails.uniq if emails.any?
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
        # Try word boundary patterns (space-word-space, start-word-space, space-word-end)
        boundary_patterns = [
          " #{single_word} ",  # word surrounded by spaces
          "#{single_word} ",   # word at start
          " #{single_word}",   # word at end
          single_word          # exact match (already tried above, but included for completeness)
        ]
        
        boundary_conditions = boundary_patterns.map do |pattern|
          "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
        end.join(" OR ")
        
        boundary_params = boundary_patterns.flat_map { |pattern| ["%#{pattern}%"] * 4 }
        
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
        contact.email_list.each { |email| emails << email }
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
      return exact_matches.map(&:full_name)
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
        # Try word boundary patterns (space-word-space, start-word-space, space-word-end)
        boundary_patterns = [
          " #{single_word} ",  # word surrounded by spaces
          "#{single_word} ",   # word at start
          " #{single_word}",   # word at end
          single_word          # exact match (already tried above, but included for completeness)
        ]
        
        boundary_conditions = boundary_patterns.map do |pattern|
          "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
        end.join(" OR ")
        
        boundary_params = boundary_patterns.flat_map { |pattern| ["%#{pattern}%"] * 4 }
        
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
    
    # Limit to top 3 most relevant contacts
    matching_contacts.limit(3).map(&:full_name)
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
      word_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
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

  def build_from_search_condition(search_term, message_type)
    return nil if search_term.blank?
    
    # Get emails from fuzzy contact search
    contact_emails = fuzzy_contact_emails(search_term)
    
    if message_type == 'linkedin'
      # For LinkedIn, search participants (from_name, to_name) and also include direct term search
      conditions = ["from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE", "%#{search_term}%", "%#{search_term}%"]
      
      # Add email-based search if we found matching contacts
      if contact_emails.any?
        email_conditions = contact_emails.map { "from_name LIKE ? COLLATE NOCASE OR to_name LIKE ? COLLATE NOCASE" }.join(" OR ")
        email_params = contact_emails.flat_map { |email| ["%#{email}%", "%#{email}%"] }
        conditions[0] += " OR #{email_conditions}"
        conditions.concat(email_params)
      end
    else
      # For Email, search both sender and recipient fields (both directions)
      conditions = [
        "sender_email LIKE ? OR sender_name LIKE ? OR recipient_emails LIKE ?", 
        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
      ]
      
      # Add email-based search if we found matching contacts (check both sender and recipient)
      if contact_emails.any?
        email_conditions = contact_emails.map { "sender_email = ? OR recipient_emails LIKE ?" }.join(" OR ")
        email_params = contact_emails.flat_map { |email| [email, "%#{email}%"] }
        conditions[0] += " OR #{email_conditions}"
        conditions.concat(email_params)
      end
    end
    
    conditions
  end

  public

  def index
    # Combined communication upload page for MBOX, LinkedIn messages, and Discord
  end

  def upload_mbox
    # Process uploaded MBOX files
    if params[:file].present?
      begin
        uploaded_file = params[:file]
        file_size = uploaded_file.size

        # For files larger than 50MB, process in background
        if file_size > 50.megabytes
          # Save the uploaded file to a temporary location
          temp_dir = Rails.root.join("tmp", "mbox_uploads")
          FileUtils.mkdir_p(temp_dir)

          temp_filename = "#{current_user.id}_#{Time.current.to_i}_#{uploaded_file.original_filename}"
          temp_path = temp_dir.join(temp_filename)

          # Copy uploaded file to temp location
          File.open(temp_path, "wb") do |file|
            file.write(uploaded_file.read)
          end

          # Queue background job
          MboxProcessingJob.perform_later(temp_path.to_s, current_user.id, uploaded_file.original_filename)

          redirect_to communications_path,
                      notice: "Large MBOX file (#{file_size / 1.megabyte}MB) queued for background processing. You'll be notified when complete."
        else
          # Process smaller files immediately
          result = MboxProcessor.new(uploaded_file, current_user).process

          message = "Successfully imported #{result[:count]} email messages."
          if result[:skipped] && result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] && result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end

          if result[:errors] && result[:errors].any?
            message += " Note: #{result[:errors].length} messages had processing errors."
          end

          redirect_to communications_path, notice: message
        end
      rescue => e
        redirect_to communications_path, alert: "Error processing MBOX file: #{e.message}"
      end
    else
      redirect_to communications_path, alert: "Please select an MBOX file to upload."
    end
  end

  def upload_linkedin_messages
    # Process uploaded LinkedIn messages CSV
    if params[:file].present?
      begin
        result = LinkedinMessagesProcessor.new(params[:file], current_user).process

        if result[:errors].any?
          error_message = "Errors occurred during import: #{result[:errors].join(', ')}"
          redirect_to communications_path, alert: error_message
        else
          message = "Successfully imported #{result[:imported]} LinkedIn messages."
          if result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end
          redirect_to communications_path, notice: message
        end
      rescue => e
        redirect_to communications_path, alert: "Error processing LinkedIn messages file: #{e.message}"
      end
    else
      redirect_to communications_path, alert: "Please select a LinkedIn messages CSV file to upload."
    end
  end

  def view
    # Show imported communication records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Determine which type of messages to show
    @message_type = params[:type] || 'email'

    # Search parameters
    @search_subject = params[:search_subject]
    @search_from = params[:search_from]
    @search_date_from = params[:search_date_from]
    @search_date_to = params[:search_date_to]

    if @message_type == 'linkedin'
      # LinkedIn messages
      linkedin_scope = current_user.linkedin_messages
      linkedin_scope = linkedin_scope.by_folder(params[:folder]) if params[:folder].present?
      
      # Apply search filters
      if @search_subject.present?
        linkedin_scope = linkedin_scope.where("subject LIKE ? COLLATE NOCASE OR content LIKE ? COLLATE NOCASE", "%#{@search_subject}%", "%#{@search_subject}%")
      end
      
      if @search_from.present?
        from_conditions = build_from_search_condition(@search_from, 'linkedin')
        linkedin_scope = linkedin_scope.where(from_conditions) if from_conditions
      end
      
      # Date range search for LinkedIn
      if @search_date_from.present? && @search_date_to.present?
        begin
          start_date = Date.parse(@search_date_from)
          end_date = Date.parse(@search_date_to)
          linkedin_scope = linkedin_scope.by_date_range(start_date.beginning_of_day, end_date.end_of_day)
        rescue ArgumentError
          # Invalid date format, ignore date filter
        end
      elsif @search_date_from.present?
        begin
          start_date = Date.parse(@search_date_from)
          linkedin_scope = linkedin_scope.where("sent_at >= ?", start_date.beginning_of_day)
        rescue ArgumentError
          # Invalid date format, ignore date filter
        end
      elsif @search_date_to.present?
        begin
          end_date = Date.parse(@search_date_to)
          linkedin_scope = linkedin_scope.where("sent_at <= ?", end_date.end_of_day)
        rescue ArgumentError
          # Invalid date format, ignore date filter
        end
      end

      @linkedin_messages = linkedin_scope.recent.limit(per_page).offset(offset)
      @total_count = linkedin_scope.count
    else
      # Email messages (default)
      @message_type = 'email'
      messages_scope = current_user.email_messages
      messages_scope = messages_scope.by_folder(params[:folder]) if params[:folder].present?
      
      # Apply search filters
      messages_scope = messages_scope.search_subject(@search_subject) if @search_subject.present?
      
      if @search_from.present?
        from_conditions = build_from_search_condition(@search_from, 'email')
        messages_scope = messages_scope.where(from_conditions) if from_conditions
      end
      
      # Date range search for Email
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
          messages_scope = messages_scope.where("received_date >= ?", start_date.beginning_of_day)
        rescue ArgumentError
          # Invalid date format, ignore date filter
        end
      elsif @search_date_to.present?
        begin
          end_date = Date.parse(@search_date_to)
          messages_scope = messages_scope.where("received_date <= ?", end_date.end_of_day)
        rescue ArgumentError
          # Invalid date format, ignore date filter
        end
      end

      @email_messages = messages_scope.recent.limit(per_page).offset(offset)
      @total_count = messages_scope.count
    end

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

    # Debug information for search
    if @search_from.present?
      @debug_contact_emails = fuzzy_contact_emails(@search_from)
      @debug_contact_names = fuzzy_contact_names(@search_from)
      @debug_search_conditions = build_from_search_condition(@search_from, @message_type)
      @debug_total_contacts = current_user.contacts.count
      @debug_detailed = debug_contact_search(@search_from)
    end

    # Statistics for both message types (use unfiltered scopes for totals)
    @total_email_messages = current_user.email_messages.count
    @total_linkedin_messages = current_user.linkedin_messages.count
    @total_size = current_user.email_messages.sum(:message_size)
    @total_messages = @message_type == 'linkedin' ? @total_linkedin_messages : @total_email_messages

    # Folders for current message type (apply search filters for accurate counts)
    if @message_type == 'linkedin'
      folder_scope = current_user.linkedin_messages
      if @search_subject.present?
        folder_scope = folder_scope.where("subject LIKE ? COLLATE NOCASE OR content LIKE ? COLLATE NOCASE", "%#{@search_subject}%", "%#{@search_subject}%")
      end
      
      if @search_from.present?
        from_conditions = build_from_search_condition(@search_from, 'linkedin')
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
    else
      folder_scope = current_user.email_messages
      folder_scope = folder_scope.search_subject(@search_subject) if @search_subject.present?
      
      if @search_from.present?
        from_conditions = build_from_search_condition(@search_from, 'email')
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
          folder_scope = folder_scope.where("received_date >= ?", start_date.beginning_of_day)
        rescue ArgumentError
        end
      elsif @search_date_to.present?
        begin
          end_date = Date.parse(@search_date_to)
          folder_scope = folder_scope.where("received_date <= ?", end_date.end_of_day)
        rescue ArgumentError
        end
      end
      
      @folders = folder_scope.group(:folder).count.sort_by { |folder, count| -count }
      @top_senders = current_user.email_messages
                                 .group(:sender_email)
                                 .order(Arel.sql("COUNT(*) DESC"))
                                 .limit(10)
                                 .count
      @date_range = {
        earliest: current_user.email_messages.minimum(:received_date),
        latest: current_user.email_messages.maximum(:received_date)
      }
    end
  end

  def show
    # Show individual email message
    @email_message = current_user.email_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to view_communications_path, alert: "Email message not found."
  end

  def clear
    # Clear all communication records for the current user
    count = current_user.email_messages.count
    current_user.email_messages.destroy_all
    redirect_to communications_path, notice: "Successfully deleted #{count} email messages."
  end
end
