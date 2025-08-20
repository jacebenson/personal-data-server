class Entertainment::AudibleController < Entertainment::BaseController
  def index
    # Show Audible upload form
    render 'entertainment/audible/upload'
  end

  def upload
    # Process uploaded Audible CSV
    if params[:file].present?
      begin
        result = Entertainment::AudibleDataProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Audible listening records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to entertainment_audible_index_path, notice: message
      rescue => e
        redirect_to entertainment_audible_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to entertainment_audible_index_path, alert: "Please select a file to upload."
    end
  end

  def show
    # Show imported Audible records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    audible_scope = current_user.entertainment_contents.audible_books
    audible_scope = audible_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      audible_scope = audible_scope.where("LOWER(title) LIKE ?", search_term)
    end

    @audible_records = audible_scope.recent.limit(per_page).offset(offset)
    @total_count = audible_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Summary stats
    @years_available = current_user.entertainment_contents.audible_books
                                  .pluck(:date_consumed)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    @total_listening_time = calculate_filtered_listening_time(audible_scope)
    
    render 'entertainment/audible/listening'
  end

  def destroy_all
    # Clear all Audible records for the current user
    count = current_user.entertainment_contents.audible_books.count
    current_user.entertainment_contents.audible_books.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Audible listening records."
  end
end
