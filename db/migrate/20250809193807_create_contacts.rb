class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.references :user, null: false, foreign_key: true

      # Core identification fields
      t.string :uid, null: false # Unique identifier from vCard or generated
      t.string :source # 'vcard', 'linkedin', 'manual', etc.
      t.string :source_file # Original filename for tracking

      # Name fields
      t.string :given_name # First name
      t.string :family_name # Last name
      t.string :middle_name
      t.string :display_name # Full name or preferred name
      t.string :nickname
      t.string :name_prefix # Dr., Mr., Mrs., etc.
      t.string :name_suffix # Jr., Sr., III, etc.

      # Organization
      t.string :organization
      t.string :job_title
      t.string :department

      # Contact information (stored as comma-separated values for multiple entries)
      t.text :emails # email1,email2,email3
      t.text :phones # phone1,phone2,phone3
      t.text :urls # website1,website2,website3

      # Address (can store as JSON for structured data)
      t.text :address

      # Additional fields
      t.date :birthday
      t.text :notes
      t.text :categories # Comma-separated list

      # Photo/Avatar
      t.string :photo_url
      t.binary :photo_data

      # Social media / messaging
      t.string :social_profiles # JSON string for multiple profiles

      # Timestamps for sync
      t.datetime :last_modified # From vCard MODIFIED field
      t.datetime :imported_at

      t.timestamps
    end

    add_index :contacts, [ :user_id, :uid ], unique: true
    add_index :contacts, [ :user_id, :given_name ]
    add_index :contacts, [ :user_id, :family_name ]
    add_index :contacts, [ :user_id, :display_name ]
    add_index :contacts, [ :user_id, :organization ]
    add_index :contacts, [ :user_id, :source ]
  end
end
