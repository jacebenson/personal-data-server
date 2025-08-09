class AmazonOrder < ApplicationRecord
  belongs_to :user

  validates :order_id, presence: true
  validates :order_date, presence: true
  validates :our_price, presence: true, numericality: true, if: :digital_order?
  validates :total_owed, presence: true, numericality: true, if: :retail_order?

  scope :recent, -> { order(order_date: :desc) }
  scope :by_year, ->(year) { where("strftime('%Y', order_date) = ?", year.to_s) }
  scope :by_status, ->(status) { where(order_status: status) }
  scope :digital, -> { where(order_type: 'digital') }
  scope :retail, -> { where(order_type: 'retail') }
  scope :subscriptions, -> { where.not(subscription_info: [nil, '', 'Not Applicable']) }
  scope :one_time_purchases, -> { where(subscription_info: [nil, '', 'Not Applicable']) }

  def self.unique_subscriptions
    subscriptions.where.not(subscription_info: [nil, '', 'Not Applicable'])
               .group(:subscription_info)
               .count
               .keys
  end

  def self.unique_subscriptions_count
    unique_subscriptions.count
  end

  def formatted_order_date
    order_date&.strftime("%B %d, %Y")
  end

  def formatted_price
    if digital_order?
      price = our_price || 0
      price == 0 ? "Free" : "$#{'%.2f' % price}"
    else
      price = total_owed || 0
      price == 0 ? "Free" : "$#{'%.2f' % price}"
    end
  end

  def price_amount
    digital_order? ? our_price : total_owed
  end

  def digital_order?
    order_type == 'digital'
  end

  def retail_order?
    order_type == 'retail'
  end

  def is_fulfilled?
    is_fulfilled == true || order_status == 'Closed'
  end

  def subscription_order?
    subscription_info.present? && subscription_info != 'Not Applicable'
  end

  def one_time_purchase?
    !subscription_order?
  end

  def subscription_id
    return nil unless subscription_order?
    # Extract subscription ID from format like "subscriptionId:1JNA33GYNFD6MV95DDJ0"
    match = subscription_info.match(/subscriptionId:([A-Z0-9]+)/)
    match ? match[1] : nil
  end

  def subscription_service
    return nil unless subscription_order?
    
    case subscription_info
    when /subscriptionId:1JNA33GYNFD6MV95DDJ0/
      "Amazon Music Unlimited"
    when /subscriptionId:5YJG0KVR272SSEJZWYP1/
      "Amazon Prime"
    when /subscriptionId:C8923XBZRNB2XH5RPS31/
      "Audible"
    when /subscriptionId:0ASE20AE3DV9FD73JCQ0/
      "Blink"
    when /subscriptionId:7B5M9BQEC81PW0TSM081/
      "Amazon Photos"
    else
      "Subscription" # Generic fallback
    end
  end
end
