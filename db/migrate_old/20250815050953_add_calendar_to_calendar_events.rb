class AddCalendarToCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    add_reference :calendar_events, :calendar, foreign_key: true
    add_index :calendar_events, [:calendar_id, :start_time]
  end
end
