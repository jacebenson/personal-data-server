class CreateSocialSecurityEarnings < ActiveRecord::Migration[8.0]
  def change
    create_table :social_security_earnings do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.decimal :fica_earnings, precision: 10, scale: 2, null: false
      t.decimal :medicare_earnings, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :social_security_earnings, [ :user_id, :year ], unique: true
  end
end
