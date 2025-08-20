class AddUniqueIndexToEntertainmentContents < ActiveRecord::Migration[8.0]
  def change
    add_index :entertainment_contents, [:user_id, :content_type, :title, :date_consumed], 
              unique: true, 
              name: 'index_entertainment_contents_unique_user_type_title_date'
  end
end
