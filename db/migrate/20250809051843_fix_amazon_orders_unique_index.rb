class FixAmazonOrdersUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the incorrect unique index
    remove_index :amazon_orders, name: 'index_amazon_orders_unique'
    
    # Add proper unique indexes
    # For digital orders: user_id + digital_order_item_id should be unique
    add_index :amazon_orders, [:user_id, :digital_order_item_id], 
              unique: true, 
              where: "order_type = 'digital' AND digital_order_item_id IS NOT NULL",
              name: 'index_amazon_orders_digital_unique'
    
    # For retail orders: user_id + order_id + asin should be unique (since same order can have multiple items)
    add_index :amazon_orders, [:user_id, :order_id, :asin], 
              unique: true, 
              where: "order_type = 'retail'",
              name: 'index_amazon_orders_retail_unique'
  end
end
