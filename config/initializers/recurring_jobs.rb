# Schedule recurring jobs
Rails.application.configure do
  if defined?(SolidQueue) && Rails.env.production?
    # In production, set up recurring calendar sync job
    config.after_initialize do
      SolidQueue::RecurringTask.create_or_find_by(
        key: "calendar_sync",
        schedule: "*/5 * * * *", # Every 5 minutes
        class_name: "CalendarSyncJob"
      ) if SolidQueue::RecurringTask.table_exists?
    end
  end
end
