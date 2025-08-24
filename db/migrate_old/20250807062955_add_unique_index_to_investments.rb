class AddUniqueIndexToInvestments < ActiveRecord::Migration[8.0]
  def change
    add_index :investments, [ :user_id, :date, :amount, :description, :account ],
              unique: true,
              name: 'index_investments_on_unique_transaction'
  end
end
