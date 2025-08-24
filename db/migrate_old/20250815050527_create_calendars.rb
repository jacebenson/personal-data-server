class CreateCalendars < ActiveRecord::Migration[8.0]
  def change
    create_table :calendars do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.string :color, default: "#3B82F6"
      t.string :source_type, null: false # file url or manual
      t.string :source_url # ics url for remote calendars
      t.datetime :last_synced_at
      t.text :sync_errors 
      t.boolean :auto_sync, default: false
      t.integer :sync_interval_minutes, default: 60
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :calendars, [:user_id, :name], unique: true
    add_index :calendars, :source_type
    add_index :calendars, :auto_sync

  end
end
