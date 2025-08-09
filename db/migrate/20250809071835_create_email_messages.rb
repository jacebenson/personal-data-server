class CreateEmailMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :email_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :message_id, null: false
      t.text :subject
      t.string :sender_email
      t.string :sender_name
      t.text :recipient_emails
      t.datetime :received_date
      t.text :content
      t.string :content_type, default: 'text/plain'
      t.string :folder
      t.integer :message_size, default: 0
      t.integer :attachments_count, default: 0

      t.timestamps
    end

    # Indexes for efficient querying
    add_index :email_messages, :message_id
    add_index :email_messages, [ :user_id, :received_date ]
    add_index :email_messages, [ :user_id, :sender_email ]
    add_index :email_messages, :folder

    # Unique constraint on message_id per user to prevent duplicates
    add_index :email_messages, [ :user_id, :message_id ], unique: true
  end
end
