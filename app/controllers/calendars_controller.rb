class CalendarsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_calendar, only: [:show, :edit, :update, :destroy, :sync]

  def index
    # Show imported calendar events with filtering and pagination
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by calendar if specified
    events_scope = current_user.calendar_events
    if params[:calendar].present?
      # Find the calendar by name and filter events by calendar_id
      calendar = current_user.calendars.find_by(name: params[:calendar])
      events_scope = events_scope.where(calendar: calendar) if calendar
    end

    # Time filter
    case params[:time_filter]
    when "upcoming"
      events_scope = events_scope.upcoming
    when "past"
      events_scope = events_scope.past
    when "today"
      events_scope = events_scope.where(start_time: Date.current.beginning_of_day..Date.current.end_of_day)
    when "this_week"
      events_scope = events_scope.where(start_time: Date.current.beginning_of_week..Date.current.end_of_week)
    when "this_month"
      events_scope = events_scope.where(start_time: Date.current.beginning_of_month..Date.current.end_of_month)
    end

    @filtered_calendar = params[:calendar]
    @time_filter = params[:time_filter]

    # Get calendar events with pagination
    @calendar_events = events_scope.order(start_time: :desc)
                                  .limit(per_page)
                                  .offset(offset)

    # Statistics
    @total_events = current_user.calendar_events.count
    @upcoming_events = current_user.calendar_events.upcoming.count
    @events_this_month = current_user.calendar_events.events_this_month_count
    @calendars = current_user.calendars
    @calendar_sources = current_user.calendars.pluck(:name).uniq

    # Pagination info
    @total_count = events_scope.count
    @total_pages = (@total_count.to_f / per_page).ceil
    @current_page = page
    @has_prev = page > 1
    @has_next = page < @total_pages

    # Additional statistics
    if @total_events > 0
      earliest = current_user.calendar_events.minimum(:start_time)
      latest = current_user.calendar_events.maximum(:start_time)
      @date_range = { earliest: earliest, latest: latest }

      # Find busiest day
      busiest = current_user.calendar_events
                           .group("DATE(start_time)")
                           .count
                           .max_by { |_, count| count }
      @busiest_day = busiest&.first
    end
  end

  def import
    # Combined calendar upload page for ICS files and URLs
  end

  def show
    # Show individual calendar details and its events
    @calendar_events = @calendar.calendar_events.order(start_time: :desc).limit(10)
  end

  def show_event
    # Show individual calendar event
    @calendar_event = current_user.calendar_events.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to calendars_path, alert: "Calendar event not found."
  end

  def new
    @calendar = Calendar.new
  end

  def create
    @calendar = current_user.calendars.build(calendar_params)

    if @calendar.save
      # sync immediately after creation
      if @calendar.sync_from_remote!
        redirect_to calendars_path, notice: "Calendar created and synced successfully."
      else
        redirect_to calendars_path, alert: "Calendar created but initial sync failed: #{@calendar.sync_errors}"
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @calendar.update(calendar_params)
      redirect_to calendars_path, notice: "Calendar '#{@calendar.name}' updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    calendar_name = @calendar.name
    event_count = @calendar.calendar_events.count

    # This will also delete associated calendar_events due to dependent: :destroy
    @calendar.destroy

    redirect_to calendars_path, notice: "Removed calendar '#{calendar_name}' and #{event_count} events."
  end

  def sync
    if @calendar.sync_from_remote!
      redirect_to calendars_path, notice: "Calendar '#{@calendar.name}' synced successfully."
    else
      redirect_to calendars_path, alert: "Calendar sync failed: #{@calendar.sync_errors}"
    end
  end

  def upload_ics_file
    # Process uploaded ICS file
    if params[:file].present?
      begin
        result = IcsProcessor.new(params[:file], current_user).process

        message = "Successfully imported #{result[:count]} calendar events"
        message += " from #{result[:calendar_name]}" if result[:calendar_name]
        message += "."

        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        if result[:errors] && result[:errors].any?
          message += " Note: #{result[:errors].length} events had processing errors."
        end

        redirect_to calendars_path, notice: message
      rescue => e
        redirect_to calendars_path, alert: "Error processing ICS file: #{e.message}"
      end
    else
      redirect_to calendars_path, alert: "Please select an ICS file to upload."
    end
  end

  def clear_all
    # Clear all calendar events for the current user
    count = current_user.calendar_events.count
    current_user.calendar_events.destroy_all
    redirect_to data_uploads_path, notice: "Successfully deleted #{count} calendar events."
  end

  private

  def set_calendar
    @calendar = current_user.calendars.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to calendars_path, alert: "Calendar not found."
  end

  def calendar_params
    params.require(:calendar).permit(:name, :description, :source_url, :color, :auto_sync, :sync_interval_minutes, :source_type)
  end
end
