class EntertainmentController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show entertainment category overview
    @netflix_count = current_user.entertainment_contents.netflix.count
    @audible_books_count = current_user.entertainment_contents.audible_books.count
    @podcasts_count = current_user.entertainment_contents.podcasts.count
    @total_content_count = current_user.entertainment_contents.count

    @last_netflix_upload = current_user.entertainment_contents.netflix.maximum(:imported_at)
    @last_audible_upload = current_user.entertainment_contents.audible_books.maximum(:imported_at)
    @last_podcast_upload = current_user.entertainment_contents.podcasts.maximum(:imported_at)
  end

  def netflix
    # Show Netflix upload form
  end

  def upload_netflix
    # Process uploaded Netflix CSV
    if params[:file].present?
      begin
        result = NetflixDataProcessor.new(params[:file].path, current_user).process

        message = "Successfully imported #{result[:count]} Netflix viewing records."
        if result[:skipped] && result[:skipped] > 0
          message += " Skipped #{result[:skipped]} records"
          if result[:duplicates] && result[:duplicates] > 0
            message += " (#{result[:duplicates]} duplicates)"
          end
          message += "."
        end

        redirect_to netflix_entertainment_index_path, notice: message
      rescue => e
        redirect_to netflix_entertainment_index_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to netflix_entertainment_index_path, alert: "Please select a file to upload."
    end
  end

  def view_netflix
    # Show imported Netflix records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by year if specified
    netflix_scope = current_user.entertainment_contents.netflix
    netflix_scope = netflix_scope.by_year(params[:filter_year]) if params[:filter_year].present?

    @netflix_records = netflix_scope.recent.limit(per_page).offset(offset)
    @total_count = netflix_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter_year = params[:filter_year]

    # Summary stats
    @years_available = current_user.entertainment_contents.netflix
                                  .pluck(:date_consumed)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    @total_hours_watched = calculate_estimated_watch_time
  end

  def clear_netflix
    # Clear all Netflix records for the current user
    count = current_user.entertainment_contents.netflix.count
    current_user.entertainment_contents.netflix.destroy_all
    redirect_to entertainment_index_path, notice: "Successfully deleted #{count} Netflix viewing records."
  end

  private

  def calculate_estimated_watch_time
    # This is a rough estimate - could be enhanced with actual runtime data
    # Assuming average content is 45 minutes (mix of movies and TV episodes)
    current_user.entertainment_contents.netflix.count * 45
  end
end
