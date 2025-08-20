class Social::LinkedinMessagesController < Social::BaseController
  def index
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
end
