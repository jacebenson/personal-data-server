class PodcastFeed < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :feed_url, presence: true, uniqueness: { scope: :user_id }
  validates :feed_url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :recently_synced, -> { where('last_synced_at > ?', 1.day.ago) }
  scope :needs_sync, -> { where('last_synced_at IS NULL OR last_synced_at < ?', 1.day.ago) }
  scope :with_errors, -> { where.not(sync_error: [nil, '']) }

  def parsed_metadata
    return {} if metadata.blank?
    JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def last_sync_status
    if sync_error.present?
      'error'
    elsif last_synced_at.present?
      'success'
    else
      'never'
    end
  end

  def sync_status_color
    case last_sync_status
    when 'error'
      'red'
    when 'success'
      'green'
    when 'never'
      'gray'
    end
  end

  def formatted_last_synced
    return "Never" unless last_synced_at
    last_synced_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def needs_sync?
    last_synced_at.nil? || last_synced_at < 1.day.ago
  end

  def domain
    URI.parse(feed_url).host
  rescue URI::InvalidURIError
    "Unknown"
  end
end
