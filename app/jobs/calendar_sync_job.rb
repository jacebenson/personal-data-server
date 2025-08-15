class CalendarSyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting calendar sync job..."
    
    # Find all calendars that need syncing
    calendars_to_sync = Calendar.active.auto_sync.select(&:needs_sync?)
    
    Rails.logger.info "Found #{calendars_to_sync.count} calendars that need syncing"
    
    calendars_to_sync.each do |calendar|
      begin
        Rails.logger.info "Syncing calendar: #{calendar.name} (ID: #{calendar.id})"
        
        if calendar.sync_from_remote!
          Rails.logger.info "Successfully synced calendar: #{calendar.name}"
        else
          Rails.logger.error "Failed to sync calendar: #{calendar.name} - #{calendar.sync_errors}"
        end
      rescue => e
        Rails.logger.error "Error syncing calendar #{calendar.name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Update the calendar with the error
        calendar.update(sync_errors: e.message)
      end
    end
    
    Rails.logger.info "Calendar sync job completed"
  end
end
