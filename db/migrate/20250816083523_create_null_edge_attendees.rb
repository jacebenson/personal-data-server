class CreateNullEdgeAttendees < ActiveRecord::Migration[8.0]
  def change
    create_table :null_edge_attendees do |t|
      t.date :date, null: false
      t.integer :count, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :null_edge_attendees, [:user_id, :date], unique: true
  end
end
