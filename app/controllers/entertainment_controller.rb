class EntertainmentController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show entertainment category overview
    @netflix_count = current_user.entertainment_contents.netflix.count
    @youtube_count = current_user.entertainment_contents.youtube.count
    @audible_books_count = current_user.entertainment_contents.audible_books.count
    @audible_library_count = current_user.entertainment_contents.audible_library.count
    @podcasts_count = current_user.entertainment_contents.podcasts.count
    @podcast_feeds_count = current_user.podcast_feeds.active.count
    @podcast_episodes_count = PodcastEpisode.joins(:podcast_feed).where(podcast_feeds: { user: current_user }).count
    @total_content_count = current_user.entertainment_contents.count

    @last_netflix_upload = current_user.entertainment_contents.netflix.maximum(:imported_at)
    @last_youtube_upload = current_user.entertainment_contents.youtube.maximum(:imported_at)
    @last_audible_upload = current_user.entertainment_contents.audible_books.maximum(:imported_at)
    @last_audible_library_upload = current_user.entertainment_contents.audible_library.maximum(:imported_at)
    @last_podcast_upload = current_user.entertainment_contents.podcasts.maximum(:imported_at)
    @last_podcast_sync = current_user.podcast_feeds.maximum(:last_synced_at)
  end

  def netflix
    # Show Netflix upload form
  end

  def upload_netflix
    # Process uploaded Netflix CSV
    if params[:file].present?
      begin
        result = NetflixDataProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Netflix viewing records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to netflix_entertainment_index_path, notice: message
      rescue => e
        redirect_to netflix_entertainment_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to netflix_entertainment_index_path, alert: "Please select a file to upload."
    end
  end

  def view_netflix
    # Show imported Netflix records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    netflix_scope = current_user.entertainment_contents.netflix
    netflix_scope = netflix_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      netflix_scope = netflix_scope.where("LOWER(title) LIKE ?", search_term)
    end

    @netflix_records = netflix_scope.recent.limit(per_page).offset(offset)
    @total_count = netflix_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Summary stats
    @years_available = current_user.entertainment_contents.netflix
                                  .pluck(:date_consumed)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    @total_hours_watched = calculate_estimated_watch_time
  end

  def clear_netflix
    # Clear all Netflix records for the current user
    count = current_user.entertainment_contents.netflix.count
    current_user.entertainment_contents.netflix.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Netflix viewing records."
  end

  # YouTube watch history methods
  def youtube
    # Show YouTube upload form
  end

  def upload_youtube
    # Process uploaded YouTube JSON
    if params[:file].present?
      begin
        result = YoutubeDataProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} YouTube watch history records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to youtube_entertainment_index_path, notice: message
      rescue => e
        redirect_to youtube_entertainment_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to youtube_entertainment_index_path, alert: "Please select a file to upload."
    end
  end

  def view_youtube
    # Show imported YouTube records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    youtube_scope = current_user.entertainment_contents.youtube
    youtube_scope = youtube_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      youtube_scope = youtube_scope.where("LOWER(title) LIKE ?", search_term)
    end

    @youtube_records = youtube_scope.recent.limit(per_page).offset(offset)
    @total_count = youtube_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Summary stats
    @years_available = current_user.entertainment_contents.youtube
                                  .pluck(:date_consumed)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    @total_videos_watched = @total_count
  end

  def clear_youtube
    # Clear all YouTube records for the current user
    count = current_user.entertainment_contents.youtube.count
    current_user.entertainment_contents.youtube.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} YouTube watch history records."
  end

  # Audible listening history methods
  def audible
    # Show Audible upload form
  end

  def upload_audible
    # Process uploaded Audible CSV
    if params[:file].present?
      begin
        result = AudibleDataProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Audible listening records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to audible_entertainment_index_path, notice: message
      rescue => e
        redirect_to audible_entertainment_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to audible_entertainment_index_path, alert: "Please select a file to upload."
    end
  end

  def view_audible
    # Show imported Audible records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    audible_scope = current_user.entertainment_contents.audible_books
    audible_scope = audible_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      audible_scope = audible_scope.where("LOWER(title) LIKE ?", search_term)
    end

    @audible_records = audible_scope.recent.limit(per_page).offset(offset)
    @total_count = audible_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Summary stats
    @years_available = current_user.entertainment_contents.audible_books
                                  .pluck(:date_consumed)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    @total_listening_time = calculate_filtered_listening_time(audible_scope)
  end

  def clear_audible
    # Clear all Audible records for the current user
    count = current_user.entertainment_contents.audible_books.count
    current_user.entertainment_contents.audible_books.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Audible listening records."
  end

  # Audible library methods
  def audible_library
    # Show Audible library upload form
  end

  def upload_audible_library
    # Process uploaded Audible Library CSV
    if params[:file].present?
      begin
        result = AudibleLibraryProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Audible library items."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to audible_library_entertainment_index_path, notice: message
      rescue => e
        redirect_to audible_library_entertainment_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to audible_library_entertainment_index_path, alert: "Please select a file to upload."
    end
  end

  def view_audible_library
    # Show imported Audible library records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    audible_library_scope = current_user.entertainment_contents.audible_library
    audible_library_scope = audible_library_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      audible_library_scope = audible_library_scope.where("LOWER(title) LIKE ?", search_term)
    end

    @audible_library_records = audible_library_scope.recent.limit(per_page).offset(offset)
    @total_count = audible_library_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Summary stats
    @years_available = current_user.entertainment_contents.audible_library
                                  .pluck(:date_consumed)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
  end

  def clear_audible_library
    # Clear all Audible library records for the current user
    count = current_user.entertainment_contents.audible_library.count
    current_user.entertainment_contents.audible_library.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Audible library items."
  end

  # Podcast feed management methods
  def podcasts
    # Show podcast feeds management page
    @podcast_feeds = current_user.podcast_feeds.active.order(:title)
    @total_feeds = @podcast_feeds.count
    @needs_sync_count = current_user.podcast_feeds.needs_sync.count
    @error_count = current_user.podcast_feeds.with_errors.count
  end

  def upload_opml
    # Process uploaded OPML file
    if params[:file].present?
      begin
        result = OpmlProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} podcast feeds."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} feeds"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to podcasts_entertainment_index_path, notice: message
      rescue => e
        redirect_to podcasts_entertainment_index_path, alert: "Error processing OPML file: #{e.message}"
      end
    else
      redirect_to podcasts_entertainment_index_path, alert: "Please select an OPML file to upload."
    end
  end

  def add_podcast_feed
    # Add a single podcast feed by URL
    feed_url = params[:feed_url]&.strip
    
    if feed_url.blank?
      redirect_to podcasts_entertainment_index_path, alert: "Please provide a podcast feed URL."
      return
    end

    begin
      # Check for existing feed
      existing_feed = current_user.podcast_feeds.find_by(feed_url: feed_url)
      if existing_feed
        redirect_to podcasts_entertainment_index_path, alert: "This podcast feed already exists."
        return
      end

      # Create the feed with minimal info
      podcast_feed = current_user.podcast_feeds.create!(
        title: "Fetching...",
        feed_url: feed_url,
        active: true
      )

      # Try to sync it immediately to get metadata
      sync_service = PodcastFeedSyncService.new(podcast_feed)
      if sync_service.sync
        redirect_to podcasts_entertainment_index_path, notice: "Successfully added podcast feed: #{podcast_feed.title}"
      else
        redirect_to podcasts_entertainment_index_path, notice: "Added podcast feed, but failed to fetch metadata. You can try syncing it manually."
      end

    rescue => e
      redirect_to podcasts_entertainment_index_path, alert: "Error adding podcast feed: #{e.message}"
    end
  end

  def sync_podcast_feed
    # Sync a specific podcast feed
    podcast_feed = current_user.podcast_feeds.find(params[:id])
    
    sync_service = PodcastFeedSyncService.new(podcast_feed)
    if sync_service.sync
      redirect_to podcasts_entertainment_index_path, notice: "Successfully synced #{podcast_feed.title}"
    else
      redirect_to podcasts_entertainment_index_path, alert: "Failed to sync #{podcast_feed.title}. Check the feed URL."
    end
  end

  def sync_all_podcast_feeds
    # Sync all active podcast feeds
    feeds_to_sync = current_user.podcast_feeds.active
    synced_count = 0
    error_count = 0

    feeds_to_sync.each do |feed|
      sync_service = PodcastFeedSyncService.new(feed)
      if sync_service.sync
        synced_count += 1
      else
        error_count += 1
      end
    end

    message = "Synced #{synced_count} podcast feeds."
    message += " #{error_count} feeds had errors." if error_count > 0

    redirect_to podcasts_entertainment_index_path, notice: message
  end

  def toggle_podcast_feed
    # Toggle active status of a podcast feed
    podcast_feed = current_user.podcast_feeds.find(params[:id])
    podcast_feed.update!(active: !podcast_feed.active)
    
    status = podcast_feed.active? ? "activated" : "deactivated"
    redirect_to podcasts_entertainment_index_path, notice: "#{podcast_feed.title} has been #{status}."
  end

  def delete_podcast_feed
    # Delete a podcast feed
    podcast_feed = current_user.podcast_feeds.find(params[:id])
    title = podcast_feed.title
    podcast_feed.destroy!
    
    redirect_to podcasts_entertainment_index_path, notice: "Deleted podcast feed: #{title}"
  end

  def clear_podcast_feeds
    # Clear all podcast feeds for the current user
    count = current_user.podcast_feeds.count
    current_user.podcast_feeds.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} podcast feeds."
  end

  def podcast_episodes
    # Show episodes for a specific podcast feed
    @podcast_feed = current_user.podcast_feeds.find(params[:id])
    
    # Simple pagination
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 20
    offset = (page - 1) * per_page

    @episodes = @podcast_feed.podcast_episodes.published_desc.limit(per_page).offset(offset)
    @total_episodes = @podcast_feed.podcast_episodes.count
    @listened_count = @podcast_feed.podcast_episodes.listened.count
    @unlistened_count = @podcast_feed.podcast_episodes.unlistened.count
    
    # Pagination info
    @current_page = page
    @total_pages = (@total_episodes.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
  end

  def podcast_episode
    # Show a specific podcast episode
    @podcast_feed = current_user.podcast_feeds.find(params[:podcast_id])
    @episode = @podcast_feed.podcast_episodes.find(params[:id])
  end

  def all_episodes
    # Show all podcast episodes across all feeds in reverse chronological order
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    episodes_scope = PodcastEpisode.joins(:podcast_feed)
                                  .where(podcast_feeds: { user_id: current_user.id })
                                  .published_desc
                                  .includes(:podcast_feed)

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      episodes_scope = episodes_scope.where(
        "LOWER(podcast_episodes.title) LIKE ? OR LOWER(podcast_episodes.description) LIKE ? OR LOWER(podcast_feeds.title) LIKE ?",
        search_term, search_term, search_term
      )
    end

    @episodes = episodes_scope.limit(per_page).offset(offset)
    @total_episodes = episodes_scope.count
    @listened_count = PodcastEpisode.joins(:podcast_feed)
                                   .where(podcast_feeds: { user_id: current_user.id })
                                   .listened.count
    
    # Pagination info
    @current_page = page
    @total_pages = (@total_episodes.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    
    # Search and pagination parameters for view
    @search_params = params[:search].present? ? { search: params[:search] } : {}
  end

  def toggle_episode_listened
    # Toggle listened status of an episode
    @podcast_feed = current_user.podcast_feeds.find(params[:podcast_id])
    @episode = @podcast_feed.podcast_episodes.find(params[:id])
    
    if @episode.listened?
      @episode.mark_as_unlistened!
      message = "Marked as unlistened"
    else
      @episode.mark_as_listened!
      message = "Marked as listened"
    end

    redirect_back_or_to(podcast_episodes_entertainment_index_path(@podcast_feed), notice: message)
  end

  private

  def calculate_estimated_watch_time
    # This is a rough estimate - could be enhanced with actual runtime data
    # Assuming average content is 45 minutes (mix of movies and TV episodes)
    current_user.entertainment_contents.netflix.count * 45
  end

  def calculate_total_listening_time
    # Calculate total listening time from Audible metadata in minutes
    total_ms = 0
    current_user.entertainment_contents.audible_books.each do |record|
      metadata = record.parsed_metadata
      if metadata['event_duration_ms']
        total_ms += metadata['event_duration_ms']
      end
    end
    total_ms / (1000 * 60) # Convert milliseconds to minutes
  end

  def calculate_filtered_listening_time(audible_scope)
    # Calculate total listening time from filtered Audible records in minutes
    total_ms = 0
    audible_scope.each do |record|
      metadata = record.parsed_metadata
      if metadata['event_duration_ms']
        total_ms += metadata['event_duration_ms']
      end
    end
    total_ms / (1000 * 60) # Convert milliseconds to minutes
  end
end
