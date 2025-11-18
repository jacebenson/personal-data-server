class AddHealthFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :weight_unit, :string
    add_column :users, :current_weight, :decimal
  end
end
