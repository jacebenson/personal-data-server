class AddUniqueIndexToBankStatements < ActiveRecord::Migration[8.0]
  def change
    # Remove existing duplicates first
    execute <<-SQL
      DELETE FROM bank_statements
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM bank_statements
        GROUP BY user_id, date, amount, description, account
      )
    SQL

    # Add unique index to prevent future duplicates
    add_index :bank_statements, [ :user_id, :date, :amount, :description, :account ],
              unique: true,
              name: 'index_bank_statements_on_unique_transaction'
  end
end
