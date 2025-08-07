class CreateInvestments < ActiveRecord::Migration[8.0]
  def change
    create_table :investments do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :date
      t.string :action
      t.string :symbol
      t.string :description
      t.string :investment_type
      t.decimal :quantity
      t.decimal :price
      t.decimal :commission
      t.decimal :fees
      t.decimal :amount
      t.string :account
      t.string :account_number
      t.datetime :settlement_date

      t.timestamps
    end
  end
end
