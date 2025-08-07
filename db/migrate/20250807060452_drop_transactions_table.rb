class DropTransactionsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :transactions do |t|
      t.integer "user_id", null: false
      t.date "date"
      t.string "description"
      t.decimal "amount"
      t.string "transaction_type"
      t.string "reference"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "user_id" ], name: "index_transactions_on_user_id"
    end
  end
end
