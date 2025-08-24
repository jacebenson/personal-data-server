class Investment < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :action, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :account, presence: true

  # Prevent duplicate transactions (including account for database-level uniqueness)
  validates :date, uniqueness: {
    scope: [ :user_id, :amount, :description, :account ],
    message: "Investment transaction already exists with the same date, amount, description, and account"
  }

  # Additional validation for application-level duplicate checking (ignoring account)
  validate :no_duplicate_transaction_ignoring_account

  scope :recent, -> { order(date: :desc) }
  scope :by_account, ->(account) { where(account: account) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_symbol, ->(symbol) { where(symbol: symbol) }

  # Helper method to find potential duplicates (ignoring account name)
  def self.find_duplicates(user_id = nil)
    scope = user_id ? where(user_id: user_id) : all
    scope.select("user_id, date, amount, description, COUNT(*) as count, GROUP_CONCAT(id) as ids, GROUP_CONCAT(account) as accounts")
         .group(:user_id, :date, :amount, :description)
         .having("COUNT(*) > 1")
  end

  # Instance method to check if this would be a duplicate (ignoring account name)
  def duplicate_exists?
    self.class.where(
      user_id: user_id,
      date: date,
      amount: amount,
      description: description
    ).where.not(id: id).exists?
  end

  # Helper method to format datetime for display
  def formatted_date
    date&.strftime("%B %d, %Y at %I:%M %p")
  end

  # Helper method to get just the date part
  def date_only
    date&.to_date
  end

  # Helper method to format amount with proper sign
  def formatted_amount
    if amount >= 0
      "+$#{amount.abs}"
    else
      "-$#{amount.abs}"
    end
  end

  private

  def no_duplicate_transaction_ignoring_account
    return unless date && amount && description && user_id

    existing = self.class.where(
      user_id: user_id,
      date: date,
      amount: amount,
      description: description
    ).where.not(id: id)

    if existing.exists?
      errors.add(:base, "An investment transaction with the same date, amount, and description already exists (possibly in a different account)")
    end
  end
end
