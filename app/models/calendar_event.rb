class CalendarEvent < ApplicationRecord
  belongs_to :user

  validates :uid, presence: true
  validates :summary, presence: true
  validates :start_time, presence: true

  # Scopes for filtering
  scope :by_calendar, ->(calendar_name) { where(calendar_name: calendar_name) }
  scope :upcoming, -> { where("start_time > ?", Time.current) }
  scope :past, -> { where("start_time < ?", Time.current) }
  scope :today, -> { where(start_time: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(start_time: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(start_time: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Ordering
  scope :chronological, -> { order(:start_time) }
  scope :reverse_chronological, -> { order(start_time: :desc) }

  # Check if event is an all-day event
  def all_day?
    all_day_event
  end

  # Duration in seconds
  def duration_seconds
    return 0 unless end_time.present?
    (end_time - start_time).to_i
  end

  # Human readable duration
  def duration_text
    return "All day" if all_day?
    return "No end time" unless end_time.present?

    seconds = duration_seconds
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 0 && minutes > 0
      "#{hours}h #{minutes}m"
    elsif hours > 0
      "#{hours}h"
    elsif minutes > 0
      "#{minutes}m"
    else
      "< 1m"
    end
  end

  # Check if event is recurring
  def recurring?
    recurrence_rule.present?
  end

  # Class methods for statistics
  def self.total_events
    count
  end

  def self.upcoming_count
    upcoming.count
  end

  def self.calendars_list
    distinct.pluck(:calendar_name).compact.sort
  end

  def self.date_range
    {
      earliest: minimum(:start_time),
      latest: maximum(:start_time)
    }
  end

  def self.events_by_calendar
    group(:calendar_name).count
  end

  def self.events_this_month_count
    this_month.count
  end

  def self.busiest_day_this_month
    this_month
      .group("DATE(start_time)")
      .count
      .max_by { |date, count| count }
      &.first
  end
end
