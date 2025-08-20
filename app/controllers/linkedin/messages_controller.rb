class Linkedin::MessagesController < Linkedin::BaseController
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
      search_condition = build_from_search_condition(@search_from)
      @debug_search_conditions = [search_condition, @search_from] if search_condition
      @debug_total_contacts = current_user.contacts.count
      @debug_detailed = debug_contact_search(@search_from)
      
      # Add the new search result information for "did you mean" functionality
      @search_result_info = @search_result
    end
  end

  def show
    @linkedin_message = current_user.linkedin_messages.find(params[:id])
  end

  private

  def build_from_search_condition(search_term)
    return nil if search_term.blank?

    # Get all potential matches with scores
    search_result = find_best_matching_names(search_term)
    
    # Store the search result for display purposes
    @search_result = search_result
    
    if search_result[:best_matches].any?
      # Build condition for exact name matches from the best results only
      name_conditions = search_result[:best_matches].map { |match| 
        escaped_name = match[:name].gsub("'", "''")
        "(from_name = '#{escaped_name}' COLLATE NOCASE OR to_name = '#{escaped_name}' COLLATE NOCASE)"
      }.join(" OR ")
      
      return "(#{name_conditions})"
    else
      # Fall back to partial search if no good matches found
      search_term_escaped = search_term.gsub("'", "''")
      return "(from_name LIKE '%#{search_term_escaped}%' COLLATE NOCASE OR to_name LIKE '%#{search_term_escaped}%' COLLATE NOCASE)"
    end
  end

  def find_best_matching_names(search_term)
    words = search_term.split(/\s+/)
    all_matches = []
    
    # Search contacts
    current_user.contacts.find_each do |contact|
      name_parts = extract_name_parts(contact)
      score = calculate_prefix_match_score(words, name_parts)
      
      if score > 0
        all_matches << {
          name: contact.display_name || contact.full_name,
          score: score,
          type: :contact,
          source: contact
        }
      end
    end
    
    # Search LinkedIn participants
    all_participants = current_user.linkedin_messages
                                  .pluck(:from_name, :to_name)
                                  .flatten
                                  .compact
                                  .uniq
    
    all_participants.each do |participant_name|
      # Handle comma-separated participant lists (group conversations)
      individual_names = participant_name.split(',').map(&:strip)
      
      individual_names.each do |individual_name|
        name_parts = individual_name.split(/[\s\-]+/).map(&:downcase)
        score = calculate_prefix_match_score(words, name_parts)
        
        if score > 0
          all_matches << {
            name: individual_name,
            score: score,
            type: :linkedin_participant,
            source: individual_name
          }
        end
      end
      
      # Also score the full participant string (for backward compatibility)
      name_parts = participant_name.split(/[\s\-]+/).map(&:downcase)
      score = calculate_prefix_match_score(words, name_parts)
      
      if score > 0
        all_matches << {
          name: participant_name,
          score: score,
          type: :linkedin_participant,
          source: participant_name
        }
      end
    end
    
    # Sort by score and determine the strategy
    all_matches.sort_by! { |m| -m[:score] }
    
    # Determine quality tiers
    if all_matches.any?
      max_score = all_matches.first[:score]
      
      # More restrictive threshold calculation
      # For multi-word searches, require high scores or significant portion of max score
      if words.length > 1
        # For multi-word searches, be much more restrictive
        high_quality_threshold = [max_score * 0.7, words.length * 7].max
      else
        # For single word searches, be more permissive  
        high_quality_threshold = [max_score * 0.6, 5].max
      end
      
      best_matches = all_matches.select { |m| m[:score] >= high_quality_threshold }
      
      # Determine strategy based on scores
      strategy = determine_search_strategy(words, best_matches, max_score)
      
      {
        original_term: search_term,
        all_matches: all_matches.first(10), # Keep top 10 for debug
        best_matches: best_matches.first(5), # Use top 5 for actual search
        strategy: strategy,
        max_score: max_score,
        threshold_used: high_quality_threshold,
        suggested_name: best_matches.first&.dig(:name)
      }
    else
      {
        original_term: search_term,
        all_matches: [],
        best_matches: [],
        strategy: :no_matches,
        max_score: 0,
        threshold_used: 0,
        suggested_name: nil
      }
    end
  end

  def determine_search_strategy(words, best_matches, max_score)
    return :no_matches if best_matches.empty?
    
    # Perfect match (all words match as prefixes or exact)
    if max_score >= words.length * 5
      :perfect_prefix_match
    # Good match (most words match well)
    elsif max_score >= words.length * 3
      :good_prefix_match
    # Partial match (some words match)
    elsif max_score >= words.length * 1
      :partial_match
    else
      :weak_match
    end
  end

  def fuzzy_contact_names_for_linkedin(search_term)
    return [] if search_term.blank?
    
    # First, try exact display name match
    exact_matches = current_user.contacts.where(
      "display_name = ? COLLATE NOCASE",
      search_term
    )
    
    if exact_matches.any?
      return exact_matches.map { |c| c.display_name || c.full_name }.compact
    end
    
    words = search_term.split(/\s+/)
    all_matches = []
    
    # Priority 1: Multi-word prefix matches (e.g., "ben f" -> "Benjamin Forrest-Green")
    if words.length > 1
      # For each contact, check if search words match word prefixes
      current_user.contacts.find_each do |contact|
        name_parts = extract_name_parts(contact)
        match_score = calculate_prefix_match_score(words, name_parts)
        
        if match_score > 0
          all_matches << {
            contact: contact,
            score: match_score,
            type: :prefix_match
          }
        end
      end
      
      # If we found good prefix matches, prioritize them
      if all_matches.any? { |m| m[:score] >= words.length }
        return all_matches
          .select { |m| m[:score] >= words.length }
          .sort_by { |m| -m[:score] }
          .map { |m| m[:contact].display_name || m[:contact].full_name }
          .compact
          .first(5)
      end
    end
    
    # Priority 2: Exact field matches for single words
    if words.length == 1
      single_word = words.first
      exact_field_matches = current_user.contacts.where(
        "display_name = ? COLLATE NOCASE OR given_name = ? COLLATE NOCASE OR family_name = ? COLLATE NOCASE",
        single_word, single_word, single_word
      )
      
      if exact_field_matches.any?
        return exact_field_matches.map { |c| c.display_name || c.full_name }.compact
      end
    end
    
    # Priority 3: Word start matches (word boundaries)
    if words.length > 1
      # For multi-word searches, require ALL words to match in the same contact
      word_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
      word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
      
      matching_contacts = current_user.contacts.where(word_conditions, *word_params)
    else
      # For single word searches, try word boundary patterns
      single_word = words.first
      boundary_patterns = [
        " #{single_word} ",  # word surrounded by spaces
        "#{single_word} ",   # word at start
        " #{single_word}",   # word at end
        "#{single_word}-",   # word before hyphen
        "-#{single_word}",   # word after hyphen
        single_word          # exact match
      ]
      
      boundary_conditions = boundary_patterns.map do |pattern|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" OR ")
      
      boundary_params = boundary_patterns.flat_map { |pattern| ["%#{pattern}%"] * 4 }
      
      matching_contacts = current_user.contacts.where(boundary_conditions, *boundary_params)
    end
    
    if matching_contacts.any?
      return matching_contacts.limit(5).map { |c| c.display_name || c.full_name }.compact
    end
    
    # Priority 4: Fall back to partial matching
    if words.length > 1
      word_conditions = words.map do |word|
        "(display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE)"
      end.join(" AND ")
      
      word_params = words.flat_map { |word| ["%#{word}%"] * 4 }
      
      fallback_contacts = current_user.contacts.where(word_conditions, *word_params)
    else
      single_word = words.first
      fallback_contacts = current_user.contacts.where(
        "display_name LIKE ? COLLATE NOCASE OR given_name LIKE ? COLLATE NOCASE OR family_name LIKE ? COLLATE NOCASE OR organization LIKE ? COLLATE NOCASE",
        "%#{single_word}%", "%#{single_word}%", "%#{single_word}%", "%#{single_word}%"
      )
    end
    
    # Return display names, limit to top 5 most relevant contacts
    fallback_contacts.limit(5).map { |c| c.display_name || c.full_name }.compact
  end

  def extract_name_parts(contact)
    parts = []
    
    # Add display name parts - this is the primary source for most contacts
    if contact.display_name.present?
      # Skip email-like display names (they won't help with name matching)
      unless contact.display_name.include?('@')
        parts.concat(contact.display_name.split(/[\s\-\.]+/))
      end
    end
    
    # Add given name (always include if present)
    if contact.given_name.present?
      parts.concat(contact.given_name.split(/[\s\-\.]+/))
    end
    
    # Add family name (always include if present)
    if contact.family_name.present?
      parts.concat(contact.family_name.split(/[\s\-\.]+/))
    end
    
    # Add organization parts if no other name parts found
    if contact.organization.present? && parts.empty?
      parts.concat(contact.organization.split(/[\s\-\.]+/))
    end
    
    # Clean up parts: lowercase, remove empty, remove common prefixes/suffixes
    clean_parts = parts.map(&:downcase)
                      .uniq
                      .reject(&:blank?)
                      .reject { |part| part.length < 1 } # Allow single letters now for "f" matching
                      .reject { |part| %w[mr mrs ms dr prof].include?(part) } # Remove titles
    
    clean_parts
  end

  def calculate_prefix_match_score(search_words, name_parts)
    score = 0
    matched_words = 0
    
    search_words.each do |search_word|
      search_word_lower = search_word.downcase
      word_score = 0
      
      # Check for exact word match (highest score)
      if name_parts.include?(search_word_lower)
        word_score = 10
        matched_words += 1
      # Check for prefix match (high score)  
      elsif name_parts.any? { |part| part.start_with?(search_word_lower) }
        # Give higher score for longer search words
        if search_word_lower.length == 1
          word_score = 8  # Single letter prefix gets good score
        elsif search_word_lower.length == 2
          word_score = 9  # Two letter prefix gets very good score
        else
          word_score = 7  # Longer prefix gets good score
        end
        matched_words += 1
      # Check for substring match (lower score)
      elsif name_parts.any? { |part| part.include?(search_word_lower) }
        if search_word_lower.length == 1
          word_score = 3  # Single letter substring gets some score
        else
          word_score = 2  # Longer substring gets lower score
        end
        # Only count as matched if it's a good substring match
        matched_words += 0.5
      end
      
      score += word_score
    end
    
    # Apply penalty for not matching all words
    # If less than 75% of words matched, apply significant penalty
    match_ratio = matched_words / search_words.length.to_f
    if match_ratio < 0.75
      score = score * match_ratio * 0.5  # Heavy penalty for partial matches
    end
    
    score
  end

  def fuzzy_linkedin_participant_names(search_term)
    return [] if search_term.blank?
    
    words = search_term.split(/\s+/)
    all_participant_matches = []
    
    # Get all unique participant names
    all_participants = current_user.linkedin_messages
                                  .pluck(:from_name, :to_name)
                                  .flatten
                                  .compact
                                  .uniq
    
    # Score each participant name
    all_participants.each do |participant_name|
      name_parts = participant_name.split(/[\s\-]+/).map(&:downcase)
      score = calculate_prefix_match_score(words, name_parts)
      
      if score > 0
        all_participant_matches << {
          name: participant_name,
          score: score
        }
      end
    end
    
    # Return top matches sorted by score
    all_participant_matches
      .sort_by { |m| -m[:score] }
      .first(5)
      .map { |m| m[:name] }
  end

  def fuzzy_contact_names(search_term)
    # Use the new comprehensive search that includes both contacts and LinkedIn participants
    contact_names = fuzzy_contact_names_for_linkedin(search_term)
    linkedin_names = fuzzy_linkedin_participant_names(search_term)
    
    (contact_names + linkedin_names).uniq
  end

  def debug_contact_search(search_term)
    return {} if search_term.blank?
    
    words = search_term.split(/\s+/)
    
    # Get the detailed search result
    search_result = find_best_matching_names(search_term)
    
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
    
    {
      original_term: search_term,
      search_words: words,
      
      # New smart search results
      smart_search_results: search_result,
      strategy_explanation: explain_strategy(search_result[:strategy]),
      
      # Legacy search results for comparison
      exact_matches: exact_matches.limit(5),
      full_term_matches: full_term_matches.limit(5),
      
      # Stats
      total_contacts_with_emails: current_user.contacts.where.not(emails: [nil, ""]).count,
      total_contacts: current_user.contacts.count,
      
      # Final results info
      suggested_name: search_result[:suggested_name],
      best_matches_count: search_result[:best_matches].length,
      total_matches_found: search_result[:all_matches].length
    }
  end

  def explain_strategy(strategy)
    case strategy
    when :perfect_prefix_match
      "🎯 Perfect Match: All search words match the beginning of name parts"
    when :good_prefix_match  
      "✅ Good Match: Most search words match well with name parts"
    when :partial_match
      "⚠️ Partial Match: Some search words found in names"
    when :weak_match
      "❌ Weak Match: Limited word matching found"
    when :no_matches
      "🚫 No Matches: No relevant names found, using partial search"
    else
      "❓ Unknown strategy"
    end
  end
end
