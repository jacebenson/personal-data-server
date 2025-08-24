class CreatePodcastFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :podcast_feeds do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :feed_url, null: false
      t.string :website_url
      t.string :image_url
      t.string :author
      t.string :category
      t.string :language
      t.datetime :last_synced_at
      t.datetime :last_episode_date
      t.integer :episode_count, default: 0
      t.boolean :active, default: true
      t.text :sync_error # Store any sync errors
      t.text :metadata # JSON field for storing additional feed data
      
      t.timestamps
    end

    add_index :podcast_feeds, [:user_id, :active]
    add_index :podcast_feeds, [:user_id, :feed_url], unique: true
    add_index :podcast_feeds, :last_synced_at
  end
end
