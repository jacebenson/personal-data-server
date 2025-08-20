class Entertainment::AudibleLibrariesController < Entertainment::BaseController
  def index
    # Show imported Audible library records with upload option
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    audible_library_scope = current_user.entertainment_contents.audible_library
    audible_library_scope = audible_library_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      audible_library_scope = audible_library_scope.where("LOWER(title) LIKE ?", search_term)
    end

    @audible_library_records = audible_library_scope.recent.limit(per_page).offset(offset)
    @total_count = audible_library_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Get available years for filter dropdown
    @available_years = current_user.entertainment_contents.audible_library
                                  .pluck(:date_consumed)
                                  .compact
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    # Summary stats (for compatibility with the view)
    @years_available = current_user.entertainment_contents.audible_library
                                  .pluck(:date_consumed)
                                  .compact
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
                                  
    render 'entertainment/audible/library'
  end

  def upload
    if request.get?
      # Show upload form
      render 'entertainment/audible_libraries/upload'
    else
      # Process uploaded Audible Library CSV
      if params[:file].present?
        begin
          result = Entertainment::AudibleLibraryProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Audible library items."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to entertainment_audible_libraries_path, notice: message
      rescue => e
        redirect_to entertainment_audible_libraries_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to entertainment_audible_libraries_path, alert: "Please select a file to upload."
    end
  end

  def show
    # Redirect to index since that's where the data display logic is now
    redirect_to entertainment_audible_libraries_path(params.permit(:page, :filter_year, :search))
  end

  def destroy_all
    # Clear all Audible library records for the current user
    count = current_user.entertainment_contents.audible_library.count
    current_user.entertainment_contents.audible_library.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Audible library items."
  end
end
