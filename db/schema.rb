# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_09_192012) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "amazon_orders", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "order_type", null: false
    t.string "order_id", null: false
    t.datetime "order_date", null: false
    t.string "asin"
    t.string "product_name"
    t.integer "quantity"
    t.string "currency_code"
    t.string "digital_order_item_id"
    t.decimal "our_price", precision: 10, scale: 2
    t.string "our_price_currency_code"
    t.decimal "list_price_amount", precision: 10, scale: 2
    t.string "list_price_currency_code"
    t.boolean "is_fulfilled"
    t.datetime "fulfilled_date"
    t.string "marketplace"
    t.string "publisher"
    t.string "ship_from"
    t.string "ship_to"
    t.boolean "is_prime_eligible"
    t.decimal "unit_price", precision: 10, scale: 2
    t.decimal "unit_price_tax", precision: 10, scale: 2
    t.decimal "shipping_charge", precision: 10, scale: 2
    t.decimal "total_discounts", precision: 10, scale: 2
    t.decimal "total_owed", precision: 10, scale: 2
    t.string "product_condition"
    t.string "payment_instrument_type"
    t.string "order_status"
    t.string "shipment_status"
    t.datetime "ship_date"
    t.string "shipping_option"
    t.text "shipping_address"
    t.text "billing_address"
    t.string "tracking_number"
    t.text "gift_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.text "subscription_info"
    t.index ["order_type"], name: "index_amazon_orders_on_order_type"
    t.index ["user_id", "digital_order_item_id"], name: "index_amazon_orders_digital_unique", unique: true, where: "order_type = 'digital' AND digital_order_item_id IS NOT NULL"
    t.index ["user_id", "order_date"], name: "index_amazon_orders_on_user_id_and_order_date"
    t.index ["user_id", "order_id", "asin"], name: "index_amazon_orders_retail_unique", unique: true, where: "order_type = 'retail'"
    t.index ["user_id"], name: "index_amazon_orders_on_user_id"
  end

  create_table "bank_statements", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "date"
    t.string "description"
    t.decimal "amount"
    t.string "account"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "date", "amount", "description", "account"], name: "index_bank_statements_on_unique_transaction", unique: true
    t.index ["user_id"], name: "index_bank_statements_on_user_id"
  end

  create_table "calendar_events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "uid", null: false
    t.string "summary", null: false
    t.text "description"
    t.string "location"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.boolean "all_day_event", default: false
    t.string "calendar_name"
    t.text "recurrence_rule"
    t.string "categories"
    t.string "status"
    t.string "organizer_email"
    t.string "organizer_name"
    t.text "attendee_emails"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_name"], name: "index_calendar_events_on_calendar_name"
    t.index ["start_time"], name: "index_calendar_events_on_start_time"
    t.index ["user_id", "start_time"], name: "index_calendar_events_on_user_id_and_start_time"
    t.index ["user_id", "uid", "calendar_name"], name: "index_calendar_events_unique", unique: true
    t.index ["user_id"], name: "index_calendar_events_on_user_id"
  end

  create_table "email_messages", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "message_id", null: false
    t.text "subject"
    t.string "sender_email"
    t.string "sender_name"
    t.text "recipient_emails"
    t.datetime "received_date"
    t.text "content"
    t.string "content_type", default: "text/plain"
    t.string "folder"
    t.integer "message_size", default: 0
    t.integer "attachments_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["folder"], name: "index_email_messages_on_folder"
    t.index ["message_id"], name: "index_email_messages_on_message_id"
    t.index ["user_id", "message_id"], name: "index_email_messages_on_user_id_and_message_id", unique: true
    t.index ["user_id", "received_date"], name: "index_email_messages_on_user_id_and_received_date"
    t.index ["user_id", "sender_email"], name: "index_email_messages_on_user_id_and_sender_email"
    t.index ["user_id"], name: "index_email_messages_on_user_id"
  end

  create_table "investments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "date"
    t.string "action"
    t.string "symbol"
    t.string "description"
    t.string "investment_type"
    t.decimal "quantity"
    t.decimal "price"
    t.decimal "commission"
    t.decimal "fees"
    t.decimal "amount"
    t.string "account"
    t.string "account_number"
    t.datetime "settlement_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "date", "amount", "description", "account"], name: "index_investments_on_unique_transaction", unique: true
    t.index ["user_id"], name: "index_investments_on_user_id"
  end

  create_table "social_security_earnings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "year", null: false
    t.decimal "fica_earnings", precision: 10, scale: 2, null: false
    t.decimal "medicare_earnings", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "year"], name: "index_social_security_earnings_on_user_id_and_year", unique: true
    t.index ["user_id"], name: "index_social_security_earnings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "amazon_orders", "users"
  add_foreign_key "bank_statements", "users"
  add_foreign_key "calendar_events", "users"
  add_foreign_key "email_messages", "users"
  add_foreign_key "investments", "users"
  add_foreign_key "social_security_earnings", "users"
end
