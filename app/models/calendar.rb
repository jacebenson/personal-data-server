require 'net/http'
require 'uri'

class Calendar < ApplicationRecord
    belongs_to :user
    has_many :calendar_events, dependent: :destroy

    validates :name, presence: true, uniqueness: { scope: :user_id }
    validates :source_type, inclusion: { in: %w[file url manual] } # Fixed: missing colon
    validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color code" }
    validates :sync_interval_minutes, numericality: { only_integer: true, greater_than: 0 }, if: :auto_sync?
    validates :source_url, presence: true, if: -> { source_type == 'url' } # Add this validation

    # Scopes - A scope is a way to specify commonly-used queries which can be referenced as method calls on the association objects or models.
    scope :active, -> { where(active: true) }
    scope :auto_sync, -> { where(auto_sync: true) }
    scope :remote, -> { where(source_type: 'url') }

    def remote_calendar?
        source_type == 'url'
    end

    def needs_sync?
        return false unless remote_calendar? && auto_sync?
        return true if last_synced_at.nil?

        last_synced_at < sync_interval_minutes.minutes.ago
    end

    def sync_from_remote!
        return unless remote_calendar? && source_url.present?

        ActiveRecord::Base.transaction do
            # Add your ICS fetching logic here
            # to do this i need to make a fetch
            ical_data = Net::HTTP.get(URI(source_url))
            # Net::HTTP is a Ruby library for making HTTP requests. The get method fetches the content of the given URL.
            calendar = Icalendar::Calendar.parse(ical_data).first
            # Icalendar is a Ruby gem for parsing and generating iCalendar files. The parse method reads the ICS data and returns an array of calendar objects. We take the first one.
            return unless calendar
            
            # Get all UIDs from the remote calendar
            remote_uids = calendar.events.map { |event| event.uid&.to_s }.compact
            
            # Find events that exist locally but not in remote (these should be deleted)
            events_to_delete = calendar_events.where.not(uid: remote_uids)
            deleted_count = events_to_delete.count
            events_to_delete.delete_all
            
            calendar.events.each do |event|
                # how to i handle events already existing?
                cal_event = calendar_events.find_or_initialize_by(uid: event.uid&.to_s)
                cal_event.assign_attributes(
                    user: self.user,
                    summary: event.summary&.to_s,
                    description: event.description&.to_s,
                    location: event.location&.to_s,
                    start_time: event.dtstart,
                    end_time: event.dtend,
                    all_day_event: event.dtstart.is_a?(Date) && !event.dtstart.is_a?(DateTime),
                    recurrence_rule: event.rrule&.to_s&.presence,
                    uid: event.uid&.to_s,
                    calendar_name: self.name
                )
                cal_event.save! if cal_event.changed?
            end
            # Update the last_synced_at timestamp and clear any previous sync errors
            
            sync_message = "Synced #{calendar.events.count} events"
            sync_message += ", deleted #{deleted_count} removed events" if deleted_count > 0
            
            update!(last_synced_at: Time.current, sync_errors: nil)
            Rails.logger.info("Calendar '#{name}' sync completed: #{sync_message}")
            
            true
        end

    rescue => e
        update!(sync_errors: e.message)
        Rails.logger.error("Calendar '#{name}' sync failed: #{e.message}")
        false
    end
end