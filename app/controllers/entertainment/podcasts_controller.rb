class Entertainment::PodcastsController < Entertainment::BaseController
  def index
    # Show podcast feeds management page
    @podcast_feeds = current_user.podcast_feeds.active.order(:title)
    @total_feeds = @podcast_feeds.count
    @needs_sync_count = current_user.podcast_feeds.needs_sync.count
    @error_count = current_user.podcast_feeds.with_errors.count
    
    render 'entertainment/podcasts/index'
  end

  def upload_opml
    # Process uploaded OPML file
    if params[:file].present?
      begin
        result = Entertainment::OpmlProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} podcast feeds."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} feeds"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to entertainment_podcasts_path, notice: message
      rescue => e
        redirect_to entertainment_podcasts_path, alert: "Error processing OPML file: #{e.message}"
      end
    else
      redirect_to entertainment_podcasts_path, alert: "Please select an OPML file to upload."
    end
  end

  def add_feed
    # Add a single podcast feed by URL
    feed_url = params[:feed_url]&.strip
    
    if feed_url.blank?
      redirect_to entertainment_podcasts_path, alert: "Please provide a podcast feed URL."
      return
    end

    begin
      # Check for existing feed
      existing_feed = current_user.podcast_feeds.find_by(feed_url: feed_url)
      if existing_feed
        redirect_to entertainment_podcasts_path, alert: "This podcast feed already exists."
        return
      end

      # Create the feed with minimal info
      podcast_feed = current_user.podcast_feeds.create!(
        title: "Fetching...",
        feed_url: feed_url,
        active: true
      )

      # Try to sync it immediately to get metadata
      sync_service = Entertainment::PodcastFeedSyncService.new(podcast_feed)
      if sync_service.sync
        redirect_to entertainment_podcasts_path, notice: "Successfully added podcast feed: #{podcast_feed.title}"
      else
        redirect_to entertainment_podcasts_path, notice: "Added podcast feed, but failed to fetch metadata. You can try syncing it manually."
      end

    rescue => e
      redirect_to entertainment_podcasts_path, alert: "Error adding podcast feed: #{e.message}"
    end
  end

  def sync
    # Sync a specific podcast feed
    podcast_feed = current_user.podcast_feeds.find(params[:id])
    
    sync_service = Entertainment::PodcastFeedSyncService.new(podcast_feed)
    if sync_service.sync
      redirect_to entertainment_podcasts_path, notice: "Successfully synced #{podcast_feed.title}"
    else
      redirect_to entertainment_podcasts_path, alert: "Failed to sync #{podcast_feed.title}. Check the feed URL."
    end
  end

  def sync_all
    # Sync all active podcast feeds
    feeds_to_sync = current_user.podcast_feeds.active
    synced_count = 0
    error_count = 0

    feeds_to_sync.each do |feed|
      sync_service = Entertainment::PodcastFeedSyncService.new(feed)
      if sync_service.sync
        synced_count += 1
      else
        error_count += 1
      end
    end

    message = "Synced #{synced_count} podcast feeds."
    message += " #{error_count} feeds had errors." if error_count > 0

    redirect_to entertainment_podcasts_path, notice: message
  end

  def toggle
    # Toggle active status of a podcast feed
    podcast_feed = current_user.podcast_feeds.find(params[:id])
    podcast_feed.update!(active: !podcast_feed.active)
    
    status = podcast_feed.active? ? "activated" : "deactivated"
    redirect_to entertainment_podcasts_path, notice: "#{podcast_feed.title} has been #{status}."
  end

  def destroy
    # Delete a podcast feed
    podcast_feed = current_user.podcast_feeds.find(params[:id])
    title = podcast_feed.title
    podcast_feed.destroy!
    
    redirect_to entertainment_podcasts_path, notice: "Deleted podcast feed: #{title}"
  end

  def destroy_all
    # Clear all podcast feeds for the current user
    count = current_user.podcast_feeds.count
    current_user.podcast_feeds.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} podcast feeds."
  end

  def episodes
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
    
    render 'entertainment/podcasts/episodes'
  end

  def episode
    # Show a specific podcast episode
    @podcast_feed = current_user.podcast_feeds.find(params[:podcast_id])
    @episode = @podcast_feed.podcast_episodes.find(params[:id])
    
    render 'entertainment/podcasts/episode'
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
    
    render 'entertainment/podcasts/all_episodes'
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

    redirect_back_or_to(episodes_entertainment_podcast_path(@podcast_feed), notice: message)
  end
end
