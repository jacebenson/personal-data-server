class AddSubscriptionInfoToAmazonOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :amazon_orders, :subscription_info, :text
  end
end
