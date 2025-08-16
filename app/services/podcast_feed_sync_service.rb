require 'open-uri'
require 'nokogiri'

class PodcastFeedSyncService
  def initialize(podcast_feed)
    @podcast_feed = podcast_feed
  end

  def sync
    begin
      # Fetch the RSS feed
      rss_content = URI.open(@podcast_feed.feed_url, 'User-Agent' => 'Personal Data Server/1.0').read
      doc = Nokogiri::XML(rss_content)
      
      # Extract feed metadata
      channel = doc.at('channel')
      return false unless channel

      # Update feed information
      @podcast_feed.update!(
        title: extract_text(channel, 'title') || @podcast_feed.title,
        description: extract_text(channel, 'description'),
        website_url: extract_text(channel, 'link') || @podcast_feed.website_url,
        author: extract_text(channel, 'author') || extract_text(channel, 'managingEditor'),
        language: extract_text(channel, 'language'),
        image_url: extract_image_url(channel),
        last_episode_date: extract_last_episode_date(doc),
        episode_count: count_episodes(doc),
        last_synced_at: Time.current,
        sync_error: nil,
        metadata: build_metadata(channel).to_json
      )

      # Sync episodes
      sync_episodes(doc)

      true
    rescue => e
      # Log the error and update the feed with error information
      Rails.logger.error "Error syncing podcast feed #{@podcast_feed.id}: #{e.message}"
      @podcast_feed.update!(
        last_synced_at: Time.current,
        sync_error: e.message
      )
      false
    end
  end

  private

  def extract_text(node, element_name)
    element = node.at(element_name)
    element&.text&.strip
  end

  def extract_image_url(channel)
    # Try different image elements
    image_url = channel.at('image/url')&.text
    image_url ||= channel.at('itunes:image')&.[]('href')
    image_url ||= channel.at('image')&.[]('href')
    image_url&.strip
  end

  def extract_last_episode_date(doc)
    # Get the publication date of the most recent episode
    latest_item = doc.at('item')
    return nil unless latest_item

    pub_date_text = extract_text(latest_item, 'pubDate')
    return nil unless pub_date_text

    begin
      # RSS dates are typically in RFC 822 format
      DateTime.parse(pub_date_text)
    rescue
      nil
    end
  end

  def count_episodes(doc)
    doc.xpath('//item').count
  end

  def sync_episodes(doc)
    # Extract all episodes from the RSS feed
    episodes = doc.xpath('//item')
    synced_count = 0
    skipped_count = 0

    episodes.each do |item|
      # Extract episode data
      guid = extract_text(item, 'guid') || extract_text(item, 'link')
      next unless guid # Skip episodes without GUID

      # Check if episode already exists
      existing_episode = @podcast_feed.podcast_episodes.find_by(guid: guid)
      if existing_episode
        skipped_count += 1
        next
      end

      # Extract episode metadata
      title = extract_text(item, 'title')
      description = extract_text(item, 'description') || extract_text(item, 'itunes:summary')
      pub_date_text = extract_text(item, 'pubDate')
      published_at = nil
      
      if pub_date_text
        begin
          published_at = DateTime.parse(pub_date_text)
        rescue
          # Ignore parsing errors
        end
      end

      # Extract audio URL and metadata
      enclosure = item.at('enclosure')
      audio_url = enclosure&.[]('url')
      file_size = enclosure&.[]('length')&.to_i
      
      # Extract iTunes-specific data
      duration = extract_text(item, 'itunes:duration')
      website_url = extract_text(item, 'link')
      
      # Build episode metadata
      episode_metadata = {
        author: extract_text(item, 'itunes:author'),
        subtitle: extract_text(item, 'itunes:subtitle'),
        explicit: extract_text(item, 'itunes:explicit'),
        episode_type: extract_text(item, 'itunes:episodeType'),
        season: extract_text(item, 'itunes:season'),
        episode: extract_text(item, 'itunes:episode'),
        keywords: extract_text(item, 'itunes:keywords'),
        content_type: enclosure&.[]('type')
      }.compact

      # Create the episode
      @podcast_feed.podcast_episodes.create!(
        title: title || 'Untitled Episode',
        description: description,
        audio_url: audio_url,
        website_url: website_url,
        published_at: published_at,
        duration: duration,
        file_size: file_size,
        guid: guid,
        metadata: episode_metadata.to_json
      )

      synced_count += 1
    end

    Rails.logger.info "Synced #{synced_count} new episodes for #{@podcast_feed.title}, skipped #{skipped_count} existing episodes"
  end

  def build_metadata(channel)
    {
      generator: extract_text(channel, 'generator'),
      copyright: extract_text(channel, 'copyright'),
      category: extract_text(channel, 'category'),
      itunes_category: channel.at('itunes:category')&.[]('text'),
      itunes_explicit: extract_text(channel, 'itunes:explicit'),
      itunes_type: extract_text(channel, 'itunes:type'),
      itunes_owner_name: extract_text(channel, 'itunes:owner/itunes:name'),
      itunes_owner_email: extract_text(channel, 'itunes:owner/itunes:email'),
      last_build_date: extract_text(channel, 'lastBuildDate'),
      ttl: extract_text(channel, 'ttl')
    }.compact
  end
end
