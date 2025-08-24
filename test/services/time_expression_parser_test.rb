# frozen_string_literal: true

require 'test_helper'

class TimeExpressionParserTest < ActiveSupport::TestCase
  # Don't use fixtures for this test
  
  test "parses recent as last 3 months" do
    range = TimeExpressionParser.parse('recent')
    
    assert_not_nil range
    # Should be approximately 3 months ago to now
    assert_in_delta 3.months.ago.to_f, range.first.to_f, 1.day.to_f
    assert_in_delta Time.current.to_f, range.last.to_f, 1.minute.to_f
  end

  test "parses today correctly" do
    range = TimeExpressionParser.parse('today')
    
    assert_not_nil range
    # Should be beginning to end of today
    assert_equal Date.current, range.first.to_date
    assert_equal Date.current, range.last.to_date
  end

  test "parses yesterday correctly" do
    range = TimeExpressionParser.parse('yesterday')
    
    assert_not_nil range
    # Should be yesterday's date
    assert_equal Date.yesterday, range.first.to_date
    assert_equal Date.yesterday, range.last.to_date
  end

  test "parses this week correctly" do
    range = TimeExpressionParser.parse('this week')
    
    assert_not_nil range
    # Should be current week boundaries
    assert_equal Date.current.beginning_of_week, range.first.to_date
    assert_equal Date.current.end_of_week, range.last.to_date
  end

  test "parses last week correctly" do
    range = TimeExpressionParser.parse('last week')
    
    assert_not_nil range
    # Should be last week's boundaries
    assert_equal 1.week.ago.beginning_of_week.to_date, range.first.to_date
    assert_equal 1.week.ago.end_of_week.to_date, range.last.to_date
  end

  test "parses specific year correctly" do
    range = TimeExpressionParser.parse('2024')
    
    assert_not_nil range
    # Should be 2024 boundaries
    assert_equal Date.new(2024, 1, 1), range.first.to_date
    assert_equal Date.new(2024, 12, 31), range.last.to_date
  end

  test "parses specific date correctly" do
    range = TimeExpressionParser.parse('2024-06-15')
    
    assert_not_nil range
    # Should be the specific date
    assert_equal Date.new(2024, 6, 15), range.first.to_date
    assert_equal Date.new(2024, 6, 15), range.last.to_date
  end

  test "handles invalid expressions gracefully" do
    range = TimeExpressionParser.parse('invalid_expression')
    
    assert_not_nil range
    # Should default to recent behavior (approximately 3 months ago to now)
    assert_in_delta 3.months.ago.to_f, range.first.to_f, 1.day.to_f
    assert_in_delta Time.current.to_f, range.last.to_f, 1.minute.to_f
  end

  test "describe_range returns human readable descriptions" do
    range = TimeExpressionParser.parse('last week')
    description = TimeExpressionParser.describe_range('last week', range)
    
    assert_includes description, 'August'
    assert_includes description, '2025'
  end

  test "describe_range handles nil timeframe" do
    range = TimeExpressionParser.parse('recent')
    description = TimeExpressionParser.describe_range(nil, range)
    
    assert_includes description, 'May'
    assert_includes description, 'August'
  end
end
