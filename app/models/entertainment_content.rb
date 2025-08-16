class EntertainmentContent < ApplicationRecord
  belongs_to :user

  validates :content_type, presence: true
  validates :title, presence: true
  validates :date_consumed, presence: true
  validates :source, presence: true

  scope :recent, -> { order(date_consumed: :desc) }
  scope :by_type, ->(type) { where(content_type: type) }
  scope :by_year, ->(year) { where("strftime('%Y', date_consumed) = ?", year.to_s) }
  scope :by_source, ->(source) { where(source: source) }
  scope :netflix, -> { where(content_type: 'netflix') }
  scope :audible_books, -> { where(content_type: 'audible_book') }
  scope :podcasts, -> { where(content_type: 'podcast') }

  def formatted_date_consumed
    date_consumed&.strftime("%B %d, %Y")
  end

  def parsed_metadata
    return {} if metadata.blank?
    JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def self.content_types
    %w[netflix audible_book podcast]
  end
end
