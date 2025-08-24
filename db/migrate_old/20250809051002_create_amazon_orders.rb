class CreateAmazonOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :amazon_orders do |t|
      t.references :user, null: false, foreign_key: true

      # Common fields for both digital and retail orders
      t.string :order_type, null: false # 'digital' or 'retail'
      t.string :order_id, null: false
      t.datetime :order_date, null: false
      t.string :asin
      t.string :product_name
      t.integer :quantity
      t.string :currency_code

      # Digital order specific fields
      t.string :digital_order_item_id
      t.decimal :our_price, precision: 10, scale: 2
      t.string :our_price_currency_code
      t.decimal :list_price_amount, precision: 10, scale: 2
      t.string :list_price_currency_code
      t.boolean :is_fulfilled
      t.datetime :fulfilled_date
      t.string :marketplace
      t.string :publisher
      t.string :ship_from
      t.string :ship_to
      t.boolean :is_prime_eligible

      # Retail order specific fields
      t.decimal :unit_price, precision: 10, scale: 2
      t.decimal :unit_price_tax, precision: 10, scale: 2
      t.decimal :shipping_charge, precision: 10, scale: 2
      t.decimal :total_discounts, precision: 10, scale: 2
      t.decimal :total_owed, precision: 10, scale: 2
      t.string :product_condition
      t.string :payment_instrument_type
      t.string :order_status
      t.string :shipment_status
      t.datetime :ship_date
      t.string :shipping_option
      t.text :shipping_address
      t.text :billing_address
      t.string :tracking_number
      t.text :gift_message

      t.timestamps

      # Add indexes for better performance
      t.index [ :user_id, :order_id, :order_type ], unique: true, name: 'index_amazon_orders_unique'
      t.index [ :user_id, :order_date ]
      t.index [ :order_type ]
    end
  end
end
