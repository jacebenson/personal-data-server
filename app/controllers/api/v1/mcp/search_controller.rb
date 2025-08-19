# frozen_string_literal: true

# MCP Search Controller - handles universal search across all data types
class Api::V1::Mcp::SearchController < Api::V1::Mcp::BaseController
  
  # Universal search across all personal data types
  # POST /api/v1/mcp/search_all_data
  def search_all_data
    return unless validate_required_params(:query)
    
    # Ensure we have a current user
    unless current_user
      render_error("Authentication required", :unauthorized, 
                   ["Please authenticate to access search functionality"])
      return
    end
    
    query = @sanitized_params[:query]
    timeframe = @sanitized_params[:parsed_timeframe]
    data_types = @sanitized_params[:data_types] || %w[communications financial health calendar entertainment]
    limit_per_type = (@sanitized_params[:limit] / data_types.length).ceil
    
    results = {}
    total_matches = 0
    
    # Search communications (emails, LinkedIn messages)
    if data_types.include?('communications')
      comm_results = search_communications(query, timeframe, limit_per_type)
      results[:communications] = comm_results
      total_matches += comm_results.length
    end
    
    # Search financial data (transactions, investments)
    if data_types.include?('financial')
      financial_results = search_financial(query, timeframe, limit_per_type)
      results[:financial] = financial_results
      total_matches += financial_results.length
    end
    
    # Search health data
    if data_types.include?('health')
      health_results = search_health(query, timeframe, limit_per_type)
      results[:health] = health_results
      total_matches += health_results.length
    end
    
    # Search calendar events
    if data_types.include?('calendar')
      calendar_results = search_calendar(query, timeframe, limit_per_type)
      results[:calendar] = calendar_results
      total_matches += calendar_results.length
    end
    
    # Search entertainment data (Netflix, YouTube, etc.)
    if data_types.include?('entertainment')
      entertainment_results = search_entertainment(query, timeframe, limit_per_type)
      results[:entertainment] = entertainment_results
      total_matches += entertainment_results.length
    end
    
    response_data = {
      query: query,
      timeframe: @sanitized_params[:timeframe],
      data_types: data_types,
      total_matches: total_matches,
      **results
    }
    
    context_message = build_search_context_message(query, total_matches, results)
    suggested_actions = suggest_next_actions_for_search(results)
    
    render_success(response_data, context_message, suggested_actions)
  end

  private

  def search_communications(query, timeframe, limit)
    results = []
    
    # Return empty results if no current user
    return results unless current_user
    
    # Search emails if Communication model exists
    if defined?(Communication) && current_user.respond_to?(:communications)
      email_scope = current_user.communications.where("subject ILIKE ? OR sender ILIKE ? OR content ILIKE ?", 
                                                      "%#{query}%", "%#{query}%", "%#{query}%")
      email_scope = apply_timeframe(email_scope, timeframe, :created_at) if timeframe
      
      emails = email_scope.limit(limit/2).map do |comm|
        {
          type: 'email',
          id: comm.id,
          subject: comm.subject,
          sender: comm.sender,
          date: comm.created_at,
          snippet: truncate_content(comm.content, 200)
        }
      end
      results.concat(emails)
    end
    
    # Search LinkedIn messages if LinkedinMessage model exists
    if defined?(LinkedinMessage) && current_user.respond_to?(:linkedin_messages)
      linkedin_scope = current_user.linkedin_messages.where("content ILIKE ? OR sender ILIKE ?", 
                                                           "%#{query}%", "%#{query}%")
      linkedin_scope = apply_timeframe(linkedin_scope, timeframe, :sent_at) if timeframe
      
      linkedin_messages = linkedin_scope.limit(limit/2).map do |msg|
        {
          type: 'linkedin_message',
          id: msg.id,
          sender: msg.sender,
          date: msg.sent_at,
          snippet: truncate_content(msg.content, 200)
        }
      end
      results.concat(linkedin_messages)
    end
    
    results.first(limit)
  end

  def search_financial(query, timeframe, limit)
    results = []
    
    # Return empty results if no current user
    return results unless current_user
    
    # Search bank transactions if BankStatement model exists
    if defined?(BankStatement) && current_user.respond_to?(:bank_statements)
      transaction_scope = current_user.bank_statements.where("description ILIKE ? OR category ILIKE ?", 
                                                           "%#{query}%", "%#{query}%")
      transaction_scope = apply_timeframe(transaction_scope, timeframe, :transaction_date) if timeframe
      
      transactions = transaction_scope.limit(limit/2).map do |txn|
        {
          type: 'bank_transaction',
          id: txn.id,
          description: txn.description,
          amount: txn.amount,
          date: txn.transaction_date,
          category: txn.category
        }
      end
      results.concat(transactions)
    end
    
    # Search Amazon orders if AmazonOrder model exists
    if defined?(AmazonOrder)
      order_scope = current_user.amazon_orders.where("title ILIKE ? OR category ILIKE ?", 
                                                    "%#{query}%", "%#{query}%")
      order_scope = apply_timeframe(order_scope, timeframe, :order_date) if timeframe
      
      orders = order_scope.limit(limit/2).map do |order|
        {
          type: 'amazon_order',
          id: order.id,
          title: order.title,
          amount: order.item_total,
          date: order.order_date,
          category: order.category
        }
      end
      results.concat(orders)
    end
    
    results.first(limit)
  end

  def search_health(query, timeframe, limit)
    results = []
    
    # Map model names to their association names
    model_associations = {
      'HealthWeight' => 'health_weights',
      'HealthSleep' => 'health_sleeps', 
      'HealthActivity' => 'health_activities',
      'HealthPatient' => 'health_patients'
    }
    
    # Search health data if models exist
    model_associations.each do |model_name, association_name|
      begin
        model = model_name.constantize
      rescue NameError
        # Model doesn't exist, skip it
        next
      end
      
      # Check if user has this association
      unless current_user.respond_to?(association_name)
        next
      end
      
      scope = current_user.send(association_name)
      
      # Search in relevant text fields
      text_columns = model.column_names.select { |col| %w[notes description type category].include?(col) }
      if text_columns.any?
        where_clause = text_columns.map { |col| "#{col} ILIKE ?" }.join(' OR ')
        scope = scope.where(where_clause, *(["%#{query}%"] * text_columns.length))
      end
      
      # Apply timeframe
      date_column = model.column_names.find { |col| %w[recorded_at date created_at].include?(col) }
      scope = apply_timeframe(scope, timeframe, date_column) if timeframe && date_column
      
      records = scope.limit(limit/4).map do |record|
        {
          type: model_name.underscore,
          id: record.id,
          date: record.try(:recorded_at) || record.try(:date) || record.created_at,
          data: record.attributes.except('id', 'user_id', 'created_at', 'updated_at')
        }
      end
      results.concat(records)
    rescue => e
      Rails.logger.warn "Error searching #{model_name}: #{e.message}"
      # Continue with other models
    end
    
    results.first(limit)
  end

  def search_calendar(query, timeframe, limit)
    results = []
    
    if defined?(CalendarEvent)
      event_scope = current_user.calendar_events.where("title ILIKE ? OR description ILIKE ? OR location ILIKE ?", 
                                                      "%#{query}%", "%#{query}%", "%#{query}%")
      event_scope = apply_timeframe(event_scope, timeframe, :start_time) if timeframe
      
      events = event_scope.limit(limit).map do |event|
        {
          type: 'calendar_event',
          id: event.id,
          title: event.title,
          description: truncate_content(event.description, 200),
          start_time: event.start_time,
          end_time: event.end_time,
          location: event.location
        }
      end
      results.concat(events)
    end
    
    results
  end

  def search_entertainment(query, timeframe, limit)
    results = []
    
    # Search Netflix data
    if defined?(NetflixViewingActivity)
      netflix_scope = current_user.netflix_viewing_activities.where("title ILIKE ?", "%#{query}%")
      netflix_scope = apply_timeframe(netflix_scope, timeframe, :date) if timeframe
      
      netflix_results = netflix_scope.limit(limit/3).map do |activity|
        {
          type: 'netflix_viewing',
          id: activity.id,
          title: activity.title,
          date: activity.date,
          duration: activity.duration
        }
      end
      results.concat(netflix_results)
    end
    
    # Search YouTube data
    if defined?(YoutubeWatchHistory)
      youtube_scope = current_user.youtube_watch_histories.where("title ILIKE ? OR channel ILIKE ?", 
                                                                "%#{query}%", "%#{query}%")
      youtube_scope = apply_timeframe(youtube_scope, timeframe, :watched_at) if timeframe
      
      youtube_results = youtube_scope.limit(limit/3).map do |video|
        {
          type: 'youtube_video',
          id: video.id,
          title: video.title,
          channel: video.channel,
          watched_at: video.watched_at
        }
      end
      results.concat(youtube_results)
    end
    
    # Search Audible library
    if defined?(AudibleLibraryItem)
      audible_scope = current_user.audible_library_items.where("title ILIKE ? OR author ILIKE ?", 
                                                             "%#{query}%", "%#{query}%")
      
      audible_results = audible_scope.limit(limit/3).map do |item|
        {
          type: 'audible_book',
          id: item.id,
          title: item.title,
          author: item.author,
          date_added: item.date_added
        }
      end
      results.concat(audible_results)
    end
    
    results.first(limit)
  end

  def apply_timeframe(scope, timeframe, date_column)
    return scope unless timeframe && date_column
    
    scope.where(date_column => timeframe)
  end

  def truncate_content(content, length)
    return '' if content.blank?
    
    content.length > length ? "#{content[0...length]}..." : content
  end

  def build_search_context_message(query, total_matches, results)
    if total_matches == 0
      "No matches found for '#{query}'"
    else
      data_types_with_results = results.select { |_, data| data.any? }.keys
      "Found #{total_matches} matches for '#{query}' across #{data_types_with_results.length} data types: #{data_types_with_results.join(', ')}"
    end
  end

  def suggest_next_actions_for_search(results)
    suggestions = []
    
    # Suggest person contact lookup if communications found
    if results[:communications]&.any?
      suggestions << 'find_person_contact'
    end
    
    # Suggest financial summary if financial data found
    if results[:financial]&.any?
      suggestions << 'get_financial_summary'
    end
    
    # Suggest recent mentions if any communication data found
    if results[:communications]&.any?
      suggestions << 'find_recent_mentions'
    end
    
    # Suggest content recommendations if entertainment data found
    if results[:entertainment]&.any?
      suggestions << 'discover_content_recommendations'
    end
    
    suggestions
  end
end
