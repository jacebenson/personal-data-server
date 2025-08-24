class Entertainment::YoutubeController < Entertainment::BaseController
  def index
    # Show imported YouTube records with upload option
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
    
    @total_hours_watched = calculate_estimated_watch_time(youtube_scope)
    
    # Chart data for watch time by month
    @chart_data = prepare_monthly_chart_data(youtube_scope)
  end

  def upload
    if request.get?
      # Show upload form
      render 'entertainment/youtube/upload'
    else
      # Process uploaded YouTube JSON
      if params[:file].present?
        begin
          result = Entertainment::YoutubeDataProcessor.new(params[:file].path, current_user).process

          message = "Successfully imported #{result[:count]} YouTube watch history records."
          if result[:skipped] && result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records"
            if result[:duplicates] && result[:duplicates] > 0
              message += " (#{result[:duplicates]} duplicates)"
            end
            message += "."
          end

          redirect_to entertainment_youtube_index_path, notice: message
        rescue => e
          redirect_to entertainment_youtube_index_path, alert: "Error processing file: #{e.message}"
        end
      else
        redirect_to entertainment_youtube_index_path, alert: "Please select a file to upload."
      end
    end
  end

  def show
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
    
    @total_hours_watched = calculate_estimated_watch_time(youtube_scope)
    
    # Chart data for watch time by month
    @chart_data = prepare_monthly_chart_data(youtube_scope)
    
    render 'entertainment/youtube/index'
  end

  def destroy_all
    # Clear all YouTube records for the current user
    count = current_user.entertainment_contents.youtube.count
    current_user.entertainment_contents.youtube.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} YouTube watch history records."
  end

  private

  def calculate_estimated_watch_time(scope = nil)
    # Simple estimation: assume each YouTube video is about 12 minutes on average
    # (mix of short videos ~3min, medium videos ~10min, and longer videos ~20min)
    scope ||= current_user.entertainment_contents.youtube
    total_items = scope.count
    estimated_minutes = total_items * 12
    (estimated_minutes / 60.0).round(1)
  end

  def prepare_monthly_chart_data(scope)
    # Group records by year and month, then calculate hours watched per month
    monthly_data = scope.group_by do |record|
      date = record.date_consumed
      date.strftime("%Y-%m")  # Format: "2024-01"
    end

    # Convert to chart format with estimated hours per month
    chart_data = monthly_data.map do |month_str, records|
      hours = (records.count * 12.0 / 60.0).round(1)  # 12 min average per video
      # Format for display: "Jan '24"
      date = Date.parse("#{month_str}-01")
      display_month = date.strftime("%b '%y")
      [display_month, hours]
    end

    # Sort by year and month
    chart_data.sort_by do |month_str, _|
      # Extract year from display format to sort properly
      if month_str.include?("'")
        month_part, year_part = month_str.split(" '")
        year = "20#{year_part}".to_i
        month = Date::MONTHNAMES.index(Date.parse("#{month_part} 1").strftime("%B"))
        [year, month]
      else
        [0, 0]  # fallback
      end
    end
  end
end
