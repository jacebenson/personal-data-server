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

ActiveRecord::Schema[8.0].define(version: 2025_08_15_050953) do
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
    t.integer "calendar_id"
    t.index ["calendar_id", "start_time"], name: "index_calendar_events_on_calendar_id_and_start_time"
    t.index ["calendar_id"], name: "index_calendar_events_on_calendar_id"
    t.index ["calendar_name"], name: "index_calendar_events_on_calendar_name"
    t.index ["start_time"], name: "index_calendar_events_on_start_time"
    t.index ["user_id", "start_time"], name: "index_calendar_events_on_user_id_and_start_time"
    t.index ["user_id", "uid", "calendar_name"], name: "index_calendar_events_unique", unique: true
    t.index ["user_id"], name: "index_calendar_events_on_user_id"
  end

  create_table "calendars", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "color", default: "#3B82F6"
    t.string "source_type", null: false
    t.string "source_url"
    t.datetime "last_synced_at"
    t.text "sync_errors"
    t.boolean "auto_sync", default: false
    t.integer "sync_interval_minutes", default: 60
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auto_sync"], name: "index_calendars_on_auto_sync"
    t.index ["source_type"], name: "index_calendars_on_source_type"
    t.index ["user_id", "name"], name: "index_calendars_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_calendars_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "uid", null: false
    t.string "source"
    t.string "source_file"
    t.string "given_name"
    t.string "family_name"
    t.string "middle_name"
    t.string "display_name"
    t.string "nickname"
    t.string "name_prefix"
    t.string "name_suffix"
    t.string "organization"
    t.string "job_title"
    t.string "department"
    t.text "emails"
    t.text "phones"
    t.text "urls"
    t.text "address"
    t.date "birthday"
    t.text "notes"
    t.text "categories"
    t.string "photo_url"
    t.binary "photo_data"
    t.string "social_profiles"
    t.datetime "last_modified"
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "display_name"], name: "index_contacts_on_user_id_and_display_name"
    t.index ["user_id", "family_name"], name: "index_contacts_on_user_id_and_family_name"
    t.index ["user_id", "given_name"], name: "index_contacts_on_user_id_and_given_name"
    t.index ["user_id", "organization"], name: "index_contacts_on_user_id_and_organization"
    t.index ["user_id", "source"], name: "index_contacts_on_user_id_and_source"
    t.index ["user_id", "uid"], name: "index_contacts_on_user_id_and_uid", unique: true
    t.index ["user_id"], name: "index_contacts_on_user_id"
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

  create_table "health_allergies", force: :cascade do |t|
    t.integer "health_patient_id", null: false
    t.string "allergen"
    t.string "reaction"
    t.string "severity"
    t.string "status"
    t.string "onset_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_patient_id", "allergen"], name: "index_health_allergies_on_health_patient_id_and_allergen", unique: true
    t.index ["health_patient_id"], name: "index_health_allergies_on_health_patient_id"
  end

  create_table "health_encounters", force: :cascade do |t|
    t.integer "health_patient_id", null: false
    t.string "encounter_date"
    t.string "encounter_type"
    t.text "reason_for_visit"
    t.string "provider_name"
    t.string "provider_specialty"
    t.string "facility_name"
    t.string "encounter_status"
    t.text "diagnosis"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_patient_id"], name: "index_health_encounters_on_health_patient_id"
  end

  create_table "health_immunizations", force: :cascade do |t|
    t.integer "health_patient_id", null: false
    t.string "vaccine_name"
    t.string "vaccine_code"
    t.string "administration_date"
    t.string "administrator"
    t.string "lot_number"
    t.string "site"
    t.string "route"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_patient_id"], name: "index_health_immunizations_on_health_patient_id"
  end

  create_table "health_medications", force: :cascade do |t|
    t.integer "health_patient_id", null: false
    t.string "medication_name"
    t.string "dosage"
    t.string "frequency"
    t.string "route"
    t.string "start_date"
    t.string "end_date"
    t.string "status"
    t.string "prescriber"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_patient_id", "medication_name", "dosage", "start_date"], name: "index_health_medications_unique", unique: true
    t.index ["health_patient_id"], name: "index_health_medications_on_health_patient_id"
  end

  create_table "health_patients", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "birth_date"
    t.string "gender"
    t.text "address"
    t.string "phone"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "health_problems", force: :cascade do |t|
    t.integer "health_patient_id", null: false
    t.string "problem_name"
    t.string "code"
    t.string "code_system"
    t.string "status"
    t.string "onset_date"
    t.string "resolved_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_patient_id", "problem_name", "code", "onset_date"], name: "index_health_problems_unique", unique: true
    t.index ["health_patient_id"], name: "index_health_problems_on_health_patient_id"
  end

  create_table "health_vital_signs", force: :cascade do |t|
    t.integer "health_patient_id", null: false
    t.string "measurement_date"
    t.decimal "height"
    t.decimal "weight"
    t.decimal "bmi"
    t.integer "systolic_bp"
    t.integer "diastolic_bp"
    t.integer "heart_rate"
    t.decimal "temperature"
    t.integer "respiratory_rate"
    t.decimal "oxygen_saturation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_patient_id"], name: "index_health_vital_signs_on_health_patient_id"
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

  create_table "linkedin_messages", force: :cascade do |t|
    t.string "conversation_id"
    t.string "conversation_title"
    t.string "from_name"
    t.string "from_profile_url"
    t.string "to_name"
    t.string "to_profile_url"
    t.datetime "sent_at"
    t.string "subject"
    t.text "content"
    t.string "folder"
    t.text "attachments"
    t.boolean "is_draft"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_linkedin_messages_on_user_id"
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
  add_foreign_key "calendar_events", "calendars"
  add_foreign_key "calendar_events", "users"
  add_foreign_key "calendars", "users"
  add_foreign_key "contacts", "users"
  add_foreign_key "email_messages", "users"
  add_foreign_key "health_allergies", "health_patients"
  add_foreign_key "health_encounters", "health_patients"
  add_foreign_key "health_immunizations", "health_patients"
  add_foreign_key "health_medications", "health_patients"
  add_foreign_key "health_problems", "health_patients"
  add_foreign_key "health_vital_signs", "health_patients"
  add_foreign_key "investments", "users"
  add_foreign_key "linkedin_messages", "users"
  add_foreign_key "social_security_earnings", "users"
end
