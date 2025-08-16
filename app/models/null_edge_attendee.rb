class NullEdgeAttendee < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :date, uniqueness: { scope: :user_id }

  scope :recent, -> { order(date: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :this_year, -> { where(date: Date.current.beginning_of_year..Date.current.end_of_year) }
  scope :this_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }
  
  def formatted_date
    date&.strftime("%B %d, %Y")
  end
end
