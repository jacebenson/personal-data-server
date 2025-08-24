# frozen_string_literal: true

# MCP Content Controller - handles content recommendations and favorite media discovery
class Api::V1::Mcp::ContentController < Api::V1::Mcp::BaseController
  # Get personalized content recommendations
  # POST /api/v1/mcp/discover_content_recommendations
  def discover_content_recommendations
    content_type = params[:content_type] || "books"
    mood = params[:mood]
    timeframe = @sanitized_params[:parsed_timeframe]
    based_on = params[:based_on] || "preferences"

    recommendations = generate_content_recommendations(content_type, mood, timeframe, based_on)

    response_data = {
      content_type: content_type,
      mood: mood,
      timeframe: @sanitized_params[:timeframe],
      based_on: based_on,
      recommendations: recommendations,
      recommendation_count: recommendations.length
    }

    context_message = build_content_recommendations_context(content_type, recommendations, mood)
    suggested_actions = [ "find_favorite_media", "search_all_data" ]

    render_success(response_data, context_message, suggested_actions)
  end

  # Discover favorite content from specific time periods
  # POST /api/v1/mcp/find_favorite_media
  def find_favorite_media
    media_type = params[:media_type] || "videos"
    timeframe = @sanitized_params[:parsed_timeframe] || TimeExpressionParser.parse("2020")
    sort_by = params[:sort_by] || "rating"
    limit = @sanitized_params[:limit]

    favorites = find_favorite_media_content(media_type, timeframe, sort_by, limit)

    response_data = {
      media_type: media_type,
      timeframe: @sanitized_params[:timeframe] || "2020",
      sort_by: sort_by,
      limit: limit,
      favorites: favorites,
      total_found: favorites.length
    }

    context_message = build_favorite_media_context(media_type, favorites, timeframe)
    suggested_actions = [ "discover_content_recommendations", "search_all_data" ]

    render_success(response_data, context_message, suggested_actions)
  end

  private

  def generate_content_recommendations(content_type, mood, timeframe, based_on)
    recommendations = []

    case content_type.downcase
    when "books", "audiobooks"
      recommendations = recommend_books(mood, timeframe, based_on)
    when "videos", "movies", "shows"
      recommendations = recommend_videos(mood, timeframe, based_on)
    when "podcasts"
      recommendations = recommend_podcasts(mood, timeframe, based_on)
    when "music"
      recommendations = recommend_music(mood, timeframe, based_on)
    else
      recommendations = recommend_general_content(content_type, mood, timeframe, based_on)
    end

    recommendations
  end

  def recommend_books(mood, timeframe, based_on)
    recommendations = []

    # Check Audible library for patterns
    if defined?(AudibleLibraryItem)
      # Find books from user's library that match mood/preferences
      audible_books = current_user.audible_library_items.limit(50)

      # Filter by mood if specified
      if mood.present?
        case mood.downcase
        when "learning", "educational"
          audible_books = audible_books.where("title LIKE ? COLLATE NOCASE OR title LIKE ? COLLATE NOCASE OR title LIKE ? COLLATE NOCASE",
                                             "%how to%", "%guide%", "%master%")
        when "relaxing", "fiction"
          audible_books = audible_books.where("title LIKE ? COLLATE NOCASE OR title LIKE ? COLLATE NOCASE", "%novel%", "%story%")
        when "motivational", "self-help"
          audible_books = audible_books.where("title LIKE ? COLLATE NOCASE OR title LIKE ? COLLATE NOCASE", "%success%", "%life%")
        end
      end

      # Convert to recommendations
      recommendations = audible_books.limit(10).map do |book|
        {
          type: "audiobook",
          title: book.title,
          author: book.author,
          reason: determine_book_recommendation_reason(book, mood, based_on),
          source: "audible_library",
          date_added: book.date_added
        }
      end

      # Add some popular recommendations based on mood if library is limited
      if recommendations.length < 5
        popular_recommendations = get_popular_book_recommendations(mood)
        recommendations.concat(popular_recommendations)
      end
    else
      # Fallback to general recommendations
      recommendations = get_popular_book_recommendations(mood)
    end

    recommendations.first(10)
  end

  def recommend_videos(mood, timeframe, based_on)
    recommendations = []

    # Analyze YouTube watch history
    if defined?(YoutubeWatchHistory)
      youtube_scope = current_user.youtube_watch_histories
      youtube_scope = youtube_scope.where(watched_at: timeframe) if timeframe

      # Find channels user watches frequently
      popular_channels = youtube_scope.group(:channel)
                                    .count
                                    .sort_by { |_, count| -count }
                                    .first(5)
                                    .map(&:first)

      recommendations.concat(
        popular_channels.map do |channel|
          {
            type: "youtube_channel",
            title: "More videos from #{channel}",
            reason: "You've watched several videos from this channel",
            source: "youtube_history"
          }
        end
      )
    end

    # Analyze Netflix viewing patterns
    if defined?(NetflixViewingActivity)
      netflix_scope = current_user.netflix_viewing_activities
      netflix_scope = netflix_scope.where(date: timeframe) if timeframe

      # Find genres or series patterns
      watched_titles = netflix_scope.pluck(:title).uniq

      recommendations.concat(
        watched_titles.first(5).map do |title|
          {
            type: "netflix_similar",
            title: "Content similar to #{title}",
            reason: "Based on your viewing of #{title}",
            source: "netflix_history"
          }
        end
      )
    end

    # Add mood-based general recommendations
    if mood.present?
      mood_recommendations = get_mood_based_video_recommendations(mood)
      recommendations.concat(mood_recommendations)
    end

    recommendations.first(10)
  end

  def recommend_podcasts(mood, timeframe, based_on)
    recommendations = []

    if defined?(PodcastFeed)
      # Get user's current podcast subscriptions
      subscribed_feeds = current_user.podcast_feeds.where(active: true)

      recommendations = subscribed_feeds.limit(10).map do |feed|
        {
          type: "podcast_episode",
          title: "Latest episodes from #{feed.title}",
          description: feed.description,
          reason: "You're subscribed to this podcast",
          source: "podcast_subscriptions"
        }
      end

      # Recommend similar podcasts based on subscriptions
      if subscribed_feeds.any?
        categories = subscribed_feeds.pluck(:category).compact.uniq
        recommendations.concat(
          categories.map do |category|
            {
              type: "podcast_discovery",
              title: "Discover more #{category} podcasts",
              reason: "You listen to #{category} content",
              source: "podcast_categories"
            }
          end
        )
      end
    end

    # Add mood-based podcast recommendations
    if mood.present?
      mood_recommendations = get_mood_based_podcast_recommendations(mood)
      recommendations.concat(mood_recommendations)
    end

    recommendations.first(10)
  end

  def recommend_music(mood, timeframe, based_on)
    # Since we don't have music data in the current schema,
    # provide general mood-based recommendations
    case mood&.downcase
    when "energetic", "workout"
      [
        { type: "playlist", title: "High-energy workout playlist", reason: "Matches energetic mood" },
        { type: "playlist", title: "Upbeat pop/rock mix", reason: "Great for motivation" }
      ]
    when "relaxing", "calm"
      [
        { type: "playlist", title: "Ambient/chill playlist", reason: "Perfect for relaxation" },
        { type: "playlist", title: "Acoustic/indie mix", reason: "Calm and soothing" }
      ]
    when "focus", "productive"
      [
        { type: "playlist", title: "Instrumental focus music", reason: "Great for concentration" },
        { type: "playlist", title: "Lo-fi study beats", reason: "Helps maintain focus" }
      ]
    else
      [
        { type: "playlist", title: "Discover weekly mix", reason: "Based on your general preferences" },
        { type: "playlist", title: "Top hits compilation", reason: "Popular current music" }
      ]
    end
  end

  def recommend_general_content(content_type, mood, timeframe, based_on)
    [
      {
        type: content_type,
        title: "Personalized #{content_type} recommendations",
        reason: "Based on your #{based_on}",
        source: "general_algorithm"
      }
    ]
  end

  def find_favorite_media_content(media_type, timeframe, sort_by, limit)
    favorites = []

    case media_type.downcase
    when "videos", "youtube"
      favorites = find_favorite_youtube_content(timeframe, sort_by, limit)
    when "movies", "shows", "netflix"
      favorites = find_favorite_netflix_content(timeframe, sort_by, limit)
    when "books", "audiobooks"
      favorites = find_favorite_books(timeframe, sort_by, limit)
    when "podcasts"
      favorites = find_favorite_podcasts(timeframe, sort_by, limit)
    end

    favorites
  end

  def find_favorite_youtube_content(timeframe, sort_by, limit)
    return [] unless defined?(YoutubeWatchHistory)

    youtube_scope = current_user.youtube_watch_histories
    youtube_scope = youtube_scope.where(watched_at: timeframe) if timeframe

    case sort_by
    when "rating", "popularity"
      # Use watch frequency as a proxy for favorites
      favorites = youtube_scope.group(:title, :channel)
                              .count
                              .sort_by { |_, count| -count }
                              .first(limit)
                              .map do |(title, channel), count|
        {
          title: title,
          channel: channel,
          watch_count: count,
          type: "youtube_video",
          reason: "Watched #{count} times"
        }
      end
    when "recent"
      favorites = youtube_scope.order(watched_at: :desc)
                              .limit(limit)
                              .map do |video|
        {
          title: video.title,
          channel: video.channel,
          watched_at: video.watched_at,
          type: "youtube_video",
          reason: "Recently watched"
        }
      end
    else
      favorites = youtube_scope.limit(limit).map do |video|
        {
          title: video.title,
          channel: video.channel,
          watched_at: video.watched_at,
          type: "youtube_video"
        }
      end
    end

    favorites
  end

  def find_favorite_netflix_content(timeframe, sort_by, limit)
    return [] unless defined?(NetflixViewingActivity)

    netflix_scope = current_user.netflix_viewing_activities
    netflix_scope = netflix_scope.where(date: timeframe) if timeframe

    case sort_by
    when "rating", "duration"
      # Use total watch time as proxy for favorites
      favorites = netflix_scope.group(:title)
                              .sum(:duration)
                              .sort_by { |_, duration| -duration }
                              .first(limit)
                              .map do |title, total_duration|
        {
          title: title,
          total_watch_time: total_duration,
          type: "netflix_content",
          reason: "Total watch time: #{total_duration} minutes"
        }
      end
    when "recent"
      favorites = netflix_scope.order(date: :desc)
                              .limit(limit)
                              .map do |activity|
        {
          title: activity.title,
          date: activity.date,
          duration: activity.duration,
          type: "netflix_content",
          reason: "Recently watched"
        }
      end
    else
      favorites = netflix_scope.limit(limit).map do |activity|
        {
          title: activity.title,
          date: activity.date,
          duration: activity.duration,
          type: "netflix_content"
        }
      end
    end

    favorites
  end

  def find_favorite_books(timeframe, sort_by, limit)
    return [] unless defined?(AudibleLibraryItem)

    audible_scope = current_user.audible_library_items

    case sort_by
    when "rating"
      # Sort by rating if available, otherwise by date added
      if audible_scope.first&.respond_to?(:rating)
        audible_scope = audible_scope.where.not(rating: nil).order(rating: :desc)
      else
        audible_scope = audible_scope.order(date_added: :desc)
      end
    when "recent"
      audible_scope = audible_scope.order(date_added: :desc)
    end

    audible_scope.limit(limit).map do |book|
      favorite = {
        title: book.title,
        author: book.author,
        date_added: book.date_added,
        type: "audiobook"
      }
      favorite[:rating] = book.rating if book.respond_to?(:rating)
      favorite
    end
  end

  def find_favorite_podcasts(timeframe, sort_by, limit)
    return [] unless defined?(PodcastFeed)

    podcast_scope = current_user.podcast_feeds.where(active: true)

    case sort_by
    when "rating", "popularity"
      # Could be based on episode count or last sync date
      podcast_scope = podcast_scope.order(updated_at: :desc)
    when "recent"
      podcast_scope = podcast_scope.order(created_at: :desc)
    end

    podcast_scope.limit(limit).map do |podcast|
      {
        title: podcast.title,
        description: podcast.description,
        category: podcast.category,
        type: "podcast",
        reason: "Active subscription"
      }
    end
  end

  # Helper methods for generating fallback recommendations

  def get_popular_book_recommendations(mood)
    case mood&.downcase
    when "learning", "educational"
      [
        { type: "book", title: "Atomic Habits", author: "James Clear", reason: "Popular self-improvement book" },
        { type: "book", title: "Sapiens", author: "Yuval Noah Harari", reason: "Fascinating historical perspective" }
      ]
    when "fiction", "relaxing"
      [
        { type: "book", title: "The Seven Husbands of Evelyn Hugo", author: "Taylor Jenkins Reid", reason: "Highly rated fiction" },
        { type: "book", title: "Where the Crawdads Sing", author: "Delia Owens", reason: "Captivating storytelling" }
      ]
    else
      [
        { type: "book", title: "The Midnight Library", author: "Matt Haig", reason: "Thought-provoking and popular" },
        { type: "book", title: "Educated", author: "Tara Westover", reason: "Compelling memoir" }
      ]
    end
  end

  def get_mood_based_video_recommendations(mood)
    case mood.downcase
    when "learning", "educational"
      [
        { type: "youtube", title: "Educational YouTube channels", reason: "Perfect for learning mood" },
        { type: "documentary", title: "Science and nature documentaries", reason: "Informative and engaging" }
      ]
    when "entertaining", "comedy"
      [
        { type: "comedy", title: "Stand-up comedy specials", reason: "Great for entertainment" },
        { type: "youtube", title: "Comedy sketch channels", reason: "Light and funny content" }
      ]
    else
      [
        { type: "mixed", title: "Trending content", reason: "Popular current videos" }
      ]
    end
  end

  def get_mood_based_podcast_recommendations(mood)
    case mood&.downcase
    when "learning", "educational"
      [
        { type: "podcast", title: "TED Talks Daily", reason: "Short, educational episodes" },
        { type: "podcast", title: "Science podcasts", reason: "Perfect for learning mood" }
      ]
    when "entertaining", "comedy"
      [
        { type: "podcast", title: "Comedy podcasts", reason: "Great for entertainment" },
        { type: "podcast", title: "True crime stories", reason: "Engaging storytelling" }
      ]
    else
      [
        { type: "podcast", title: "News and current events", reason: "Stay informed" }
      ]
    end
  end

  def determine_book_recommendation_reason(book, mood, based_on)
    reasons = []

    if mood.present?
      reasons << "matches your #{mood} mood"
    end

    case based_on
    when "reading_history"
      reasons << "based on your reading history"
    when "preferences"
      reasons << "matches your preferences"
    when "similar_users"
      reasons << "recommended by similar users"
    else
      reasons << "from your library"
    end

    reasons.join(" and ")
  end

  def build_content_recommendations_context(content_type, recommendations, mood)
    if recommendations.empty?
      "No #{content_type} recommendations found"
    else
      message = "Found #{recommendations.length} #{content_type} recommendations"
      message += " for #{mood} mood" if mood.present?
      message
    end
  end

  def build_favorite_media_context(media_type, favorites, timeframe)
    if favorites.empty?
      "No favorite #{media_type} found for the specified time period"
    else
      timeframe_desc = describe_timeframe(@sanitized_params[:timeframe], timeframe)
      "Found #{favorites.length} favorite #{media_type} from #{timeframe_desc}"
    end
  end
end
