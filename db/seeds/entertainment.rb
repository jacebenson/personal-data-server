# Entertainment Data Seeds
# Creates sample entertainment and media consumption data

def seed_entertainment_data(user)
  puts "🎬 Seeding entertainment data for #{user.email}..."

  # Books/Reading data (Goodreads-style)
  books = [
    {
      content_type: "book",
      title: "The Pragmatic Programmer",
      author: "David Thomas, Andrew Hunt",
      date_consumed: 30.days.ago,
      date_read: 30.days.ago.to_date,
      my_rating: 5,
      exclusive_shelf: "read",
      number_of_pages: 352,
      year_published: 2019,
      isbn: "9780135957059",
      isbn13: "9780135957059",
      average_rating: 4.32,
      publisher: "Addison-Wesley Professional",
      binding: "Paperback",
      source: "goodreads"
    },
    {
      content_type: "book",
      title: "Clean Code",
      author: "Robert C. Martin",
      date_consumed: 45.days.ago,
      date_read: 45.days.ago.to_date,
      my_rating: 4,
      exclusive_shelf: "read",
      number_of_pages: 464,
      year_published: 2008,
      isbn: "9780132350884",
      isbn13: "9780132350884",
      average_rating: 4.15,
      publisher: "Prentice Hall",
      binding: "Paperback",
      source: "goodreads"
    },
    {
      content_type: "book",
      title: "System Design Interview",
      author: "Alex Xu",
      date_consumed: Date.current,
      my_rating: nil,
      exclusive_shelf: "currently-reading",
      number_of_pages: 280,
      year_published: 2020,
      isbn: "9798664653403",
      isbn13: "9798664653403",
      average_rating: 4.25,
      publisher: "Independently published",
      binding: "Paperback",
      source: "goodreads"
    },
    {
      content_type: "book",
      title: "Design Patterns",
      author: "Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides",
      date_consumed: Date.current,
      my_rating: nil,
      exclusive_shelf: "to-read",
      number_of_pages: 395,
      year_published: 1994,
      isbn: "9780201633610",
      isbn13: "9780201633610",
      average_rating: 4.18,
      publisher: "Addison-Wesley Professional",
      binding: "Hardcover",
      source: "goodreads"
    }
  ]

  books.each do |book|
    EntertainmentContent.find_or_create_by!(
      user: user,
      content_type: book[:content_type],
      title: book[:title],
      author: book[:author]
    ) do |content|
      content.date_consumed = book[:date_consumed]
      content.date_read = book[:date_read]
      content.my_rating = book[:my_rating]
      content.exclusive_shelf = book[:exclusive_shelf]
      content.number_of_pages = book[:number_of_pages]
      content.year_published = book[:year_published]
      content.isbn = book[:isbn]
      content.isbn13 = book[:isbn13]
      content.average_rating = book[:average_rating]
      content.publisher = book[:publisher]
      content.binding = book[:binding]
      content.source = book[:source]
      content.description = "Sample book description for #{book[:title]}"
    end
  end

  # YouTube watch history
  youtube_videos = [
    {
      content_type: "youtube",
      title: "Ruby on Rails Tutorial for Beginners",
      date_consumed: 7.days.ago,
      description: "Complete Ruby on Rails tutorial covering MVC, routing, and more",
      source: "youtube",
      metadata: { duration: "2:45:30", channel: "TechTutorials", views: "125K" }.to_json
    },
    {
      content_type: "youtube",
      title: "PostgreSQL Performance Tuning",
      date_consumed: 14.days.ago,
      description: "Advanced techniques for optimizing PostgreSQL queries",
      source: "youtube",
      metadata: { duration: "45:20", channel: "DatabasePro", views: "78K" }.to_json
    },
    {
      content_type: "youtube",
      title: "Docker Compose Deep Dive",
      date_consumed: 21.days.ago,
      description: "Comprehensive guide to Docker Compose for development",
      source: "youtube",
      metadata: { duration: "1:15:45", channel: "DevOpsDaily", views: "95K" }.to_json
    }
  ]

  youtube_videos.each do |video|
    EntertainmentContent.find_or_create_by!(
      user: user,
      content_type: video[:content_type],
      title: video[:title],
      date_consumed: video[:date_consumed]
    ) do |content|
      content.description = video[:description]
      content.source = video[:source]
      content.metadata = video[:metadata]
    end
  end

  # Netflix watch history
  netflix_shows = [
    {
      content_type: "netflix",
      title: "Stranger Things",
      date_consumed: 10.days.ago,
      description: "Sci-fi horror series set in the 1980s",
      source: "netflix",
      metadata: { season: 4, episode: 9, duration: "2:30:00", genre: "Sci-Fi/Horror" }.to_json
    },
    {
      content_type: "netflix",
      title: "The Crown",
      date_consumed: 25.days.ago,
      description: "Historical drama about the British Royal Family",
      source: "netflix",
      metadata: { season: 5, episode: 8, duration: "55:00", genre: "Drama/History" }.to_json
    }
  ]

  netflix_shows.each do |show|
    EntertainmentContent.find_or_create_by!(
      user: user,
      content_type: show[:content_type],
      title: show[:title],
      date_consumed: show[:date_consumed]
    ) do |content|
      content.description = show[:description]
      content.source = show[:source]
      content.metadata = show[:metadata]
    end
  end

  # Podcast feeds
  podcast_feeds = [
    {
      title: "The Changelog",
      description: "Conversations with the hackers, leaders, and innovators of the software world",
      feed_url: "https://changelog.com/podcast/feed",
      website_url: "https://changelog.com/podcast",
      author: "Changelog Media",
      category: "Technology",
      language: "en",
      active: true
    },
    {
      title: "Ruby Rogues",
      description: "Weekly panel discussion about Ruby programming",
      feed_url: "https://feeds.feedwrench.com/RubyRogues.rss",
      website_url: "https://rubyrogues.com",
      author: "Charles Max Wood",
      category: "Technology",
      language: "en",
      active: true
    },
    {
      title: "Software Engineering Daily",
      description: "Technical interviews about software topics",
      feed_url: "https://softwareengineeringdaily.com/feed/podcast/",
      website_url: "https://softwareengineeringdaily.com",
      author: "Jeff Meyerson",
      category: "Technology",
      language: "en",
      active: true
    }
  ]

  podcast_feeds.each do |feed_data|
    feed = PodcastFeed.find_or_create_by!(
      user: user,
      feed_url: feed_data[:feed_url]
    ) do |pf|
      pf.title = feed_data[:title]
      pf.description = feed_data[:description]
      pf.website_url = feed_data[:website_url]
      pf.author = feed_data[:author]
      pf.category = feed_data[:category]
      pf.language = feed_data[:language]
      pf.active = feed_data[:active]
      pf.episode_count = rand(50..500)
      pf.last_synced_at = 1.hour.ago
      pf.last_episode_date = 2.days.ago
    end

    # Create some sample episodes for each feed
    3.times do |i|
      episode_date = (i + 1).days.ago
      PodcastEpisode.find_or_create_by!(
        podcast_feed: feed,
        guid: "#{feed.title.downcase.gsub(' ', '-')}-episode-#{i + 1}"
      ) do |episode|
        episode.title = "Episode #{rand(100..999)}: Sample Topic #{i + 1}"
        episode.description = "This is a sample episode description for #{feed.title}"
        episode.audio_url = "https://example.com/#{feed.title.downcase.gsub(' ', '-')}/episode-#{i + 1}.mp3"
        episode.website_url = "#{feed.website_url}/episode-#{i + 1}"
        episode.published_at = episode_date
        episode.duration = "#{rand(30..120)}:#{rand(10..59).to_s.rjust(2, '0')}"
        episode.file_size = rand(20_000_000..100_000_000)
        episode.listened = i == 0 # Mark first episode as listened
        episode.listened_at = i == 0 ? episode_date + 1.hour : nil
      end
    end
  end

  puts "   ✅ Created #{EntertainmentContent.where(user: user, content_type: 'book').count} book records"
  puts "   ✅ Created #{EntertainmentContent.where(user: user, content_type: 'youtube').count} YouTube videos"
  puts "   ✅ Created #{EntertainmentContent.where(user: user, content_type: 'netflix').count} Netflix shows"
  puts "   ✅ Created #{PodcastFeed.where(user: user).count} podcast feeds"
  puts "   ✅ Created #{PodcastEpisode.joins(:podcast_feed).where(podcast_feeds: { user: user }).count} podcast episodes"
end
