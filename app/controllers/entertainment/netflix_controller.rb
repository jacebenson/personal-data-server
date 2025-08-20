class Entertainment::NetflixController < Entertainment::BaseController
  def index
    # Show imported Netflix records with upload option
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
    
    @total_hours_watched = calculate_estimated_watch_time(netflix_scope)
    
    # Chart data for watch time by month
    @chart_data = prepare_monthly_chart_data(netflix_scope)
  end

  def upload
    # Process uploaded Netflix CSV
    if params[:file].present?
      begin
        result = Entertainment::NetflixDataProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Netflix viewing records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to entertainment_netflix_index_path, notice: message
      rescue => e
        redirect_to entertainment_netflix_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to entertainment_netflix_index_path, alert: "Please select a file to upload."
    end
  end

  def show
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
    
    @total_hours_watched = calculate_estimated_watch_time(netflix_scope)
    
    # Chart data for watch time by month
    @chart_data = prepare_monthly_chart_data(netflix_scope)
    
    render 'entertainment/netflix/index'
  end

  def destroy_all
    # Clear all Netflix records for the current user
    count = current_user.entertainment_contents.netflix.count
    current_user.entertainment_contents.netflix.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Netflix viewing records."
  end

  private

  def calculate_estimated_watch_time(scope = nil)
    # Simple estimation: assume each Netflix entry is about 45 minutes on average
    # (mix of movies ~120min and TV episodes ~30min)
    scope ||= current_user.entertainment_contents.netflix
    total_items = scope.count
    estimated_minutes = total_items * 45
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
      hours = (records.count * 45.0 / 60.0).round(1)  # 45 min average per item
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
