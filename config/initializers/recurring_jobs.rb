# Schedule recurring jobs
Rails.application.configure do
  if defined?(SolidQueue) && (Rails.env.production? || Rails.env.development?)
    config.after_initialize do
      # Set up recurring calendar sync job
      SolidQueue::RecurringTask.create_or_find_by(
        key: "calendar_sync",
        schedule: "*/5 * * * *", # Every 5 minutes
        class_name: "CalendarSyncJob"
      ) if SolidQueue::RecurringTask.table_exists?
      
      # Set up recurring podcast sync job
      SolidQueue::RecurringTask.create_or_find_by(
        key: "podcast_sync",
        schedule: "*/30 * * * *", # Every 30 minutes
        class_name: "PodcastSyncJob"
      ) if SolidQueue::RecurringTask.table_exists?
    end
  end
end
