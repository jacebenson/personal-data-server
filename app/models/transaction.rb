class Transaction < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :transaction_type, presence: true

  scope :recent, -> { order(date: :desc) }
  scope :by_type, ->(type) { where(transaction_type: type) }
end
