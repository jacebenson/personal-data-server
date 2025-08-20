class Entertainment::BooksController < Entertainment::BaseController
  def index
    # Show Goodreads upload form
    render 'entertainment/books/upload'
  end

  def upload
    # Process uploaded Goodreads CSV
    if params[:file].present?
      begin
        result = Entertainment::GoodreadsDataProcessor.new(params[:file].path, current_user).process

        if result[:success]
          message = "Successfully imported #{result[:count]} Goodreads book records."
          if result[:skipped] && result[:skipped] > 0
            message += " Skipped #{result[:skipped]} records (likely duplicates)."
          end
          redirect_to entertainment_books_path, notice: message
        else
          error_message = "Error processing file"
          if result[:errors].any?
            error_message += ": #{result[:errors].first}"
          end
          redirect_to entertainment_books_path, alert: error_message
        end
      rescue => e
        redirect_to entertainment_books_path, alert: "Error processing file: #{e.message}"
      end
    else
      redirect_to entertainment_books_path, alert: "Please select a file to upload."
    end
  end

  def show
    # Show imported Goodreads records
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = 50
    offset = (page - 1) * per_page

    # Filter by shelf status if specified
    goodreads_scope = current_user.entertainment_contents.goodreads
    goodreads_scope = goodreads_scope.where(exclusive_shelf: params[:filter]) if params[:filter].present?

    # Filter by year if specified (use date_read for Goodreads)
    if params[:filter_year].present?
      goodreads_scope = goodreads_scope.where("strftime('%Y', date_read) = ?", params[:filter_year].to_s)
    end

    # Add search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      goodreads_scope = goodreads_scope.where("LOWER(title) LIKE ? OR LOWER(author) LIKE ?", search_term, search_term)
    end

    # Order by date_read for read books (most recent first), then by created_at for others
    # Books with read dates should come first, ordered by read date descending
    goodreads_scope = goodreads_scope.order(Arel.sql("date_read DESC NULLS LAST, created_at DESC"))

    @goodreads_records = goodreads_scope.limit(per_page).offset(offset)
    @total_count = goodreads_scope.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next = page < @total_pages
    @has_prev = page > 1
    @filter = params[:filter]
    @filter_year = params[:filter_year]
    @search = params[:search]

    # Summary stats
    @years_available = current_user.entertainment_contents.goodreads
                                  .where.not(date_read: nil)
                                  .pluck(:date_read)
                                  .map { |d| d.year }
                                  .uniq.sort.reverse
    
    @shelf_counts = {
      'read' => current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'read').count,
      'currently-reading' => current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'currently-reading').count,
      'to-read' => current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'to-read').count
    }

    # Calculate reading stats for read books
    read_books = current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'read')
    @books_read_this_year = read_books.where("strftime('%Y', date_read) = ?", Date.current.year.to_s).count
    rated_books = read_books.where('my_rating > ?', 0)
    @average_rating = rated_books.any? ? rated_books.average(:my_rating) : 0
    
    render 'entertainment/books/index'
  end

  def destroy_all
    # Clear all Goodreads records for the current user
    count = current_user.entertainment_contents.goodreads.count
    current_user.entertainment_contents.goodreads.destroy_all
    redirect_to entertainment_path, notice: "Successfully deleted #{count} Goodreads book records."
  end
end
