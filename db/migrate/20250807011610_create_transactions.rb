class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.string :description
      t.decimal :amount
      t.string :transaction_type
      t.string :reference

      t.timestamps
    end
  end
end
