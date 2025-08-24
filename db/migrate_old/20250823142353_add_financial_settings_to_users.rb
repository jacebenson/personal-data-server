class AddFinancialSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :investment_goal, :decimal
    add_column :users, :discretionary_account, :string
  end
end
