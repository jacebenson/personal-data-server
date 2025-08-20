class EntertainmentController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show entertainment category overview
    @netflix_count = current_user.entertainment_contents.netflix.count
    @youtube_count = current_user.entertainment_contents.youtube.count
    @audible_books_count = current_user.entertainment_contents.audible_books.count
    @audible_library_count = current_user.entertainment_contents.audible_library.count
    @podcasts_count = current_user.entertainment_contents.podcasts.count
    @podcast_feeds_count = current_user.podcast_feeds.active.count
    @podcast_episodes_count = PodcastEpisode.joins(:podcast_feed).where(podcast_feeds: { user: current_user }).count
    @total_content_count = current_user.entertainment_contents.count

    # Books (Goodreads) data
    @books_read_count = current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'read').count
    @books_currently_reading_count = current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'currently-reading').count
    @books_to_read_count = current_user.entertainment_contents.goodreads.where(exclusive_shelf: 'to-read').count
    
    # Calculate average rating for read books (only books with ratings > 0)
    read_books_with_ratings = current_user.entertainment_contents.goodreads
                                         .where(exclusive_shelf: 'read')
                                         .where('my_rating > ?', 0)
    @average_rating = read_books_with_ratings.any? ? read_books_with_ratings.average(:my_rating) : 0

    @last_netflix_upload = current_user.entertainment_contents.netflix.maximum(:imported_at)
    @last_youtube_upload = current_user.entertainment_contents.youtube.maximum(:imported_at)
    @last_audible_upload = current_user.entertainment_contents.audible_books.maximum(:imported_at)
    @last_audible_library_upload = current_user.entertainment_contents.audible_library.maximum(:imported_at)
    @last_podcast_upload = current_user.entertainment_contents.podcasts.maximum(:imported_at)
    @last_podcast_sync = current_user.podcast_feeds.maximum(:last_synced_at)
    @last_goodreads_upload = current_user.entertainment_contents.goodreads.maximum(:imported_at)
  end
end
