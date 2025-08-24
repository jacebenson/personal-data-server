class CreateCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :uid, null: false
      t.string :summary, null: false
      t.text :description
      t.string :location
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.boolean :all_day_event, default: false
      t.string :calendar_name
      t.text :recurrence_rule
      t.string :categories
      t.string :status
      t.string :organizer_email
      t.string :organizer_name
      t.text :attendee_emails
      t.timestamps
    end

    add_index :calendar_events, [ :user_id, :uid, :calendar_name ], unique: true, name: "index_calendar_events_unique"
    add_index :calendar_events, :start_time
    add_index :calendar_events, :calendar_name
    add_index :calendar_events, [ :user_id, :start_time ]
  end
end
