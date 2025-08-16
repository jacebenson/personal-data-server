class CreatePodcastEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :podcast_episodes do |t|
      t.references :podcast_feed, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :audio_url
      t.string :website_url
      t.datetime :published_at
      t.string :duration
      t.integer :file_size
      t.string :guid, null: false # GUID is required for RSS feed uniqueness
      t.boolean :listened, default: false
      t.datetime :listened_at
      t.text :metadata # JSON field for storing additional episode data

      t.timestamps
    end

    # Add indexes for common queries
    add_index :podcast_episodes, [:podcast_feed_id, :published_at]
    add_index :podcast_episodes, [:podcast_feed_id, :guid], unique: true
    add_index :podcast_episodes, :published_at
    add_index :podcast_episodes, :listened
  end
end
