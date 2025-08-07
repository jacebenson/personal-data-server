class BankStatement < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :account, presence: true

  # Prevent duplicate transactions
  validates :date, uniqueness: {
    scope: [ :user_id, :amount, :description, :account ],
    message: "Transaction already exists with the same date, amount, description, and account"
  }

  scope :recent, -> { order(date: :desc) }
  scope :by_account, ->(account) { where(account: account) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }

  # Helper method to find potential duplicates
  def self.find_duplicates(user_id = nil)
    scope = user_id ? where(user_id: user_id) : all
    scope.select("user_id, date, amount, description, account, COUNT(*) as count")
         .group(:user_id, :date, :amount, :description, :account)
         .having("COUNT(*) > 1")
  end

  # Instance method to check if this would be a duplicate
  def duplicate_exists?
    self.class.where(
      user_id: user_id,
      date: date,
      amount: amount,
      description: description,
      account: account
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
end
