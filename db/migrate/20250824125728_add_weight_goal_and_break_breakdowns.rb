class AddWeightGoalAndBreakBreakdowns < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :weight_goal, :decimal, precision: 4, scale: 2

    # weight_breakdown will make equal parts between the first logged weight, and the goal weight
    # as such we only need this to be at most 99 or less
    # precision 4 means a total of 4 digits, with 2 digits after the decimal point
    # we can use a precision of 2 (0-99) with zero digits after the decimal point
    # so precision of 2 (0-99) with zero digits after the decimal point (scale=0)
    add_column :users, :weight_breakdown, :decimal, precision: 2, scale: 0
    add_column :users, :investment_breakdown, :decimal, precision: 2, scale: 0
  end
end
