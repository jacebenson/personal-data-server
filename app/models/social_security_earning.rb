class SocialSecurityEarning < ApplicationRecord
  belongs_to :user

  validates :year, presence: true, uniqueness: { scope: :user_id }
  validates :fica_earnings, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :medicare_earnings, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :by_year, -> { order(:year) }
  scope :recent_years, ->(count = 10) { order(year: :desc).limit(count) }
end
