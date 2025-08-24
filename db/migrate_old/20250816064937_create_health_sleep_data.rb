class CreateHealthSleepData < ActiveRecord::Migration[8.0]
  def change
    create_table :health_sleep_data do |t|
      t.references :health_patient, null: false, foreign_key: true
      t.string :session_date
      t.decimal :usage_hours
      t.integer :sleep_score
      t.decimal :ahi_score
      t.integer :leak_score
      t.integer :mask_score
      t.integer :usage_score
      t.integer :mask_session_count
      t.decimal :ahi
      t.decimal :leak_50_percentile
      t.decimal :leak_70_percentile
      t.decimal :leak_95_percentile
      t.string :mode
      t.string :device_serial

      t.timestamps
    end
  end
end
