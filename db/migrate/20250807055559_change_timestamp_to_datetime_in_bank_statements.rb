class ChangeTimestampToDatetimeInBankStatements < ActiveRecord::Migration[8.0]
  def change
    # Change the date column to datetime to preserve time information
    change_column :bank_statements, :date, :datetime
  end
end
