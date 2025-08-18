class CategoriesController < ApplicationController
  before_action :authenticate_user!

  def financial
    @bank_statements_count = current_user.bank_statements.count
    @investments_count = current_user.investments.count
    @ssa_earnings_count = current_user.social_security_earnings.count
    @amazon_orders_count = current_user.amazon_orders.count

    @last_bank_upload = current_user.bank_statements.maximum(:created_at)
    @last_investment_upload = current_user.investments.maximum(:created_at)
    @last_ssa_upload = current_user.social_security_earnings.maximum(:created_at)
    @last_amazon_upload = current_user.amazon_orders.maximum(:created_at)
  end

  def personal
    # Personal data counts
    @email_messages_count = current_user.email_messages.count
    @linkedin_messages_count = current_user.linkedin_messages.count
    @communications_count = @email_messages_count + @linkedin_messages_count
    @health_records_count = 0
    @contacts_count = current_user.contacts.count
    @calendar_events_count = current_user.calendar_events.count
    @content_items_count = 0
  end

  def entertainment
    # Entertainment data counts
    @netflix_count = current_user.entertainment_contents.netflix.count
    @youtube_count = current_user.entertainment_contents.youtube.count
    @audible_books_count = current_user.entertainment_contents.audible_books.count
    @audible_library_count = current_user.entertainment_contents.audible_library.count
    @podcasts_count = current_user.entertainment_contents.podcasts.count
    @podcast_feeds_count = current_user.podcast_feeds.active.count
    @podcast_episodes_count = PodcastEpisode.joins(:podcast_feed).where(podcast_feeds: { user: current_user }).count
    @total_content_count = current_user.entertainment_contents.count

    @last_netflix_upload = current_user.entertainment_contents.netflix.maximum(:imported_at)
    @last_youtube_upload = current_user.entertainment_contents.youtube.maximum(:imported_at)
    @last_audible_upload = current_user.entertainment_contents.audible_books.maximum(:imported_at)
    @last_audible_library_upload = current_user.entertainment_contents.audible_library.maximum(:imported_at)
    @last_podcast_upload = current_user.entertainment_contents.podcasts.maximum(:imported_at)
    @last_podcast_sync = current_user.podcast_feeds.maximum(:last_synced_at)
  end
end
