class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :bank_statements, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :social_security_earnings, dependent: :destroy
  has_many :amazon_orders, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :entertainment_contents, dependent: :destroy
  has_many :podcast_feeds, dependent: :destroy
  has_many :null_edge_attendees, dependent: :destroy

  # Validations
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true
  validates :investment_goal, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :investment_breakdown, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight_goal, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight_breakdown, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Get user's timezone or default
  def user_timezone
    timezone.presence || "Central Time (US & Canada)"
  end

  # Get today's date in user's timezone
  def current_date_in_timezone
    Time.zone = user_timezone
    Time.zone.today
  end

  # Get events for today in user's timezone
  def todays_events
    Time.zone = user_timezone
    today_start = Time.zone.today.beginning_of_day
    today_end = Time.zone.today.end_of_day
    calendar_events.where(start_time: today_start..today_end).chronological
  end

  # Generate a stable Bearer token based on user attributes
  def bearer_token
    return @bearer_token if @bearer_token

    # Create a stable hash from user attributes
    token_data = "#{email}:#{encrypted_password}:#{created_at.to_i}"
    digest = Digest::SHA256.hexdigest(token_data)
    @bearer_token = "pds_#{digest[0..31]}" # 32-char token with prefix
  end

  # Validate a Bearer token for this user
  def valid_bearer_token?(token)
    bearer_token == token
  end

  # Class method to find user by Bearer token
  def self.find_by_bearer_token(token)
    return nil unless token&.start_with?("pds_")

    # Since tokens are deterministic, we need to check all users
    # In production, consider adding a bearer_token column for performance
    User.all.find { |user| user.valid_bearer_token?(token) }
  end
end
