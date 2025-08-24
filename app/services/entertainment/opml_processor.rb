require 'nokogiri'
require 'open-uri'

module Entertainment
  class OpmlProcessor
  def initialize(file_path, user)
    @file_path = file_path
    @user = user
    @imported_count = 0
    @skipped_count = 0
    @duplicate_count = 0
    @errors = []
  end

  def process
    begin
      # Parse the OPML file
      doc = File.open(@file_path) { |f| Nokogiri::XML(f) }
      
      # Find all outline elements that represent podcast feeds
      outlines = doc.xpath('//outline[@type="rss" or @xmlUrl or contains(@type, "rss")]')
      
      outlines.each_with_index do |outline, index|
        process_outline(outline, index + 1)
      end

      {
        count: @imported_count,
        skipped: @skipped_count,
        duplicates: @duplicate_count,
        errors: @errors
      }
    rescue => e
      Rails.logger.error "OPML processing error: #{e.message}"
      raise e
    end
  end

  private

  def process_outline(outline, row_number)
    begin
      # Extract feed information from OPML outline
      title = outline['title'] || outline['text'] || 'Unknown Podcast'
      feed_url = outline['xmlUrl']
      website_url = outline['htmlUrl']
      description = outline['description']
      category = outline['category']

      # Skip if no feed URL
      if feed_url.blank?
        @skipped_count += 1
        return
      end

      # Clean up the URLs
      feed_url = feed_url.strip
      website_url = website_url&.strip

      # Check for existing feed (to avoid duplicates)
      existing_feed = @user.podcast_feeds.find_by(feed_url: feed_url)
      if existing_feed
        @duplicate_count += 1
        @skipped_count += 1
        return
      end

      # Create the podcast feed record
      @user.podcast_feeds.create!(
        title: title.strip,
        description: description&.strip,
        feed_url: feed_url,
        website_url: website_url,
        category: category&.strip,
        active: true
      )

      @imported_count += 1

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
      Rails.logger.error "Error processing OPML outline #{row_number}: #{e.message}"
    end
  end
end
end
