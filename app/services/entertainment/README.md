# Entertainment Services

This directory contains all service classes related to entertainment content processing and management.

## Service Classes

### Data Processors
- **`netflix_data_processor.rb`** - Processes Netflix viewing history CSV files
- **`youtube_data_processor.rb`** - Processes YouTube watch history JSON files  
- **`audible_data_processor.rb`** - Processes Audible listening history CSV files
- **`audible_library_processor.rb`** - Processes Audible library CSV files
- **`goodreads_data_processor.rb`** - Processes Goodreads library export CSV files
- **`opml_processor.rb`** - Processes OPML podcast subscription files

### Sync Services
- **`podcast_feed_sync_service.rb`** - Syncs podcast feeds and episodes from RSS URLs

## Usage

All classes are namespaced under the `Entertainment` module:

```ruby
# Netflix data processing
processor = Entertainment::NetflixDataProcessor.new(file_path, user)
result = processor.process

# YouTube data processing  
processor = Entertainment::YoutubeDataProcessor.new(file_path, user)
result = processor.process

# Goodreads data processing
processor = Entertainment::GoodreadsDataProcessor.new(file_path, user)
result = processor.process

# Podcast feed syncing
sync_service = Entertainment::PodcastFeedSyncService.new(podcast_feed)
success = sync_service.sync
```

## Return Format

All data processors return a hash with the following format:

```ruby
{
  success: true/false,
  count: number_of_processed_records,
  skipped: number_of_skipped_records,
  errors: array_of_error_messages
}
```

## Models

All processed data is stored in the `EntertainmentContent` model with different `content_type` values:
- `netflix` - Netflix viewing records
- `youtube` - YouTube watch history
- `audible_book` - Audible listening history
- `audible_library` - Audible library items
- `goodreads` - Goodreads book records
- `podcast` - Podcast episodes (via feeds)

## Controller

The `EntertainmentController` coordinates all entertainment-related functionality and uses these services for data processing.
