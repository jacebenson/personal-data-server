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
  has_many :email_messages, dependent: :destroy
  has_many :linkedin_messages, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :entertainment_contents, dependent: :destroy
  has_many :podcast_feeds, dependent: :destroy
  has_many :null_edge_attendees, dependent: :destroy

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
    return nil unless token&.start_with?('pds_')
    
    # Since tokens are deterministic, we need to check all users
    # In production, consider adding a bearer_token column for performance
    User.all.find { |user| user.valid_bearer_token?(token) }
  end
end
