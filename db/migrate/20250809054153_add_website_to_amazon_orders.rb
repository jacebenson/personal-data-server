class AddWebsiteToAmazonOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :amazon_orders, :website, :string
  end
end
