class CreateLinkedinMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :linkedin_messages do |t|
      t.string :conversation_id
      t.string :conversation_title
      t.string :from_name
      t.string :from_profile_url
      t.string :to_name
      t.string :to_profile_url
      t.datetime :sent_at
      t.string :subject
      t.text :content
      t.string :folder
      t.text :attachments
      t.boolean :is_draft
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :linkedin_messages, [:user_id, :conversation_id]
    add_index :linkedin_messages, [:user_id, :sent_at]
    add_index :linkedin_messages, [:user_id, :from_name]
    add_index :linkedin_messages, [:user_id, :folder]
  end
end
