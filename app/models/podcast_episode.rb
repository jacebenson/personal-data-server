class PodcastEpisode < ApplicationRecord
  belongs_to :podcast_feed

  validates :title, presence: true
  validates :guid, presence: true, uniqueness: { scope: :podcast_feed_id }

  scope :published_desc, -> { order(published_at: :desc) }
  scope :published_asc, -> { order(published_at: :asc) }
  scope :listened, -> { where(listened: true) }
  scope :unlistened, -> { where(listened: false) }
  scope :recent, -> (limit = 10) { published_desc.limit(limit) }

  def parsed_metadata
    return {} if metadata.blank?
    JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def mark_as_listened!
    update!(listened: true, listened_at: Time.current)
  end

  def mark_as_unlistened!
    update!(listened: false, listened_at: nil)
  end

  def formatted_duration
    return duration if duration.blank? || duration.match?(/^\d{1,2}:\d{2}(:\d{2})?$/)
    
    # Convert seconds to HH:MM:SS or MM:SS format
    if duration.match?(/^\d+$/)
      seconds = duration.to_i
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60
      
      if hours > 0
        "%d:%02d:%02d" % [hours, minutes, secs]
      else
        "%d:%02d" % [minutes, secs]
      end
    else
      duration
    end
  end

  def formatted_file_size
    return nil if file_size.blank?
    
    # Convert bytes to human readable format
    units = ['B', 'KB', 'MB', 'GB']
    size = file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "%.1f %s" % [size, units[unit_index]]
  end

  def short_description(length = 200)
    return nil if description.blank?
    
    # Strip HTML tags and truncate
    plain_text = ActionView::Base.full_sanitizer.sanitize(description)
    truncate(plain_text, length: length)
  end

  private

  def truncate(text, length:)
    return text if text.length <= length
    text[0...length].gsub(/\s+\S*$/, '') + '...'
  end
end
