class CreateEntertainmentContents < ActiveRecord::Migration[8.0]
  def change
    create_table :entertainment_contents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :content_type, null: false # 'netflix', 'audible_book', 'podcast', etc.
      t.string :title, null: false
      t.datetime :date_consumed, null: false
      t.text :metadata # JSON field for storing content-specific data
      t.text :description
      t.string :source # The platform/service name
      t.datetime :imported_at, default: -> { 'CURRENT_TIMESTAMP' }
      
      t.timestamps
    end

    add_index :entertainment_contents, [:user_id, :content_type]
    add_index :entertainment_contents, [:user_id, :date_consumed]
    add_index :entertainment_contents, [:user_id, :title]
  end
end
