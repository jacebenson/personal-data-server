class AddGoodreadsFieldsToEntertainmentContents < ActiveRecord::Migration[8.0]
  def change
    add_column :entertainment_contents, :author, :string
    add_column :entertainment_contents, :my_rating, :integer
    add_column :entertainment_contents, :exclusive_shelf, :string
    add_column :entertainment_contents, :date_read, :date
    add_column :entertainment_contents, :number_of_pages, :integer
    add_column :entertainment_contents, :year_published, :integer
    add_column :entertainment_contents, :original_publication_year, :integer
    add_column :entertainment_contents, :isbn, :string
    add_column :entertainment_contents, :isbn13, :string
    add_column :entertainment_contents, :book_id, :integer
    add_column :entertainment_contents, :average_rating, :decimal, precision: 3, scale: 2
    add_column :entertainment_contents, :publisher, :string
    add_column :entertainment_contents, :binding, :string
    add_column :entertainment_contents, :additional_authors, :text

    # Add indexes for commonly queried fields
    add_index :entertainment_contents, [:user_id, :content_type, :exclusive_shelf], name: 'index_entertainment_contents_on_user_type_shelf'
    add_index :entertainment_contents, [:user_id, :content_type, :author], name: 'index_entertainment_contents_on_user_type_author'
    add_index :entertainment_contents, [:user_id, :content_type, :date_read], name: 'index_entertainment_contents_on_user_type_date_read'
  end
end
