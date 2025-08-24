class PodcastSyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting podcast sync job..."
    
    # Find all podcast feeds that need syncing
    # Similar to calendars, we'll sync feeds that haven't been synced recently
    feeds_to_sync = PodcastFeed.active.needs_sync
    
    Rails.logger.info "Found #{feeds_to_sync.count} podcast feeds that need syncing"
    
    synced_count = 0
    failed_count = 0
    
    feeds_to_sync.each do |feed|
      begin
        Rails.logger.info "Syncing podcast feed: #{feed.title || feed.url} (ID: #{feed.id})"
        
        sync_service = PodcastFeedSyncService.new(feed)
        if sync_service.sync
          synced_count += 1
          Rails.logger.info "Successfully synced podcast feed: #{feed.title || feed.url}"
        else
          failed_count += 1
          Rails.logger.error "Failed to sync podcast feed: #{feed.title || feed.url}"
        end
      rescue => e
        failed_count += 1
        Rails.logger.error "Error syncing podcast feed #{feed.title || feed.url}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Mark the feed as having an error
        feed.update(sync_error: e.message)
      end
    end
    
    Rails.logger.info "Podcast sync job completed - synced: #{synced_count}, failed: #{failed_count}"
  end
end
