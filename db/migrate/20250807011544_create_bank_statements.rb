class CreateBankStatements < ActiveRecord::Migration[8.0]
  def change
    create_table :bank_statements do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.string :description
      t.decimal :amount
      t.string :account
      t.string :category

      t.timestamps
    end
  end
end
