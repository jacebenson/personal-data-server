# frozen_string_literal: true

require 'test_helper'

class Api::V1::Mcp::FinancialControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
    
    # Set up HTTP Basic Auth
    @auth_headers = { 
      'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email, 'password123'),
      'Content-Type' => 'application/json'
    }
  end

  teardown do
    User.destroy_all
  end

  test "get_financial_summary returns proper MCP format" do
    post '/api/v1/mcp/get_financial_summary',
         params: { timeframe: 'recent', include_forecasts: true }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'get_financial_summary', json_response['action']
    assert_not_nil json_response['result']
    assert_not_nil json_response['context']
    assert_not_nil json_response['suggested_next_actions']
    assert_not_nil json_response['timestamp']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['timeframe']
    assert_not_nil result['include_forecasts']
    assert_not_nil result['accounts']
    assert_not_nil result['summary']
  end

  test "analyze_spending_pattern returns proper MCP format" do
    post '/api/v1/mcp/analyze_spending_pattern',
         params: { category: 'dining', timeframe: 'last month' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'analyze_spending_pattern', json_response['action']
    assert_not_nil json_response['result']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['category']
    assert_not_nil result['timeframe']
    assert_not_nil result['analysis']
    assert_not_nil result['spending_breakdown']
  end

  test "calculate_savings_potential returns proper MCP format" do
    post '/api/v1/mcp/calculate_savings_potential',
         params: { timeframe: 'recent', focus_categories: ['subscriptions', 'dining'] }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'calculate_savings_potential', json_response['action']
    assert_not_nil json_response['result']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['timeframe']
    assert_not_nil result['focus_categories']
    assert_not_nil result['opportunities']
    assert_not_nil result['potential_monthly_savings']
  end

  test "handles different timeframes correctly" do
    post '/api/v1/mcp/get_financial_summary',
         params: { timeframe: 'this year' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'this year', result['timeframe']
  end

  test "provides meaningful financial context" do
    post '/api/v1/mcp/get_financial_summary',
         params: { timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_not_empty json_response['context']
    assert_includes json_response['context'].downcase, 'financial'
  end

  test "handles spending category analysis" do
    post '/api/v1/mcp/analyze_spending_pattern',
         params: { category: 'entertainment', timeframe: 'last month' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'entertainment', result['category']
    assert_not_nil result['analysis']
  end

  test "calculates savings opportunities" do
    post '/api/v1/mcp/calculate_savings_potential',
         params: { 
           timeframe: 'recent', 
           focus_categories: ['subscriptions', 'dining', 'entertainment'] 
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal ['subscriptions', 'dining', 'entertainment'], result['focus_categories']
    assert_not_nil result['opportunities']
    assert result['opportunities'].is_a?(Array)
  end

  test "includes investment data when available" do
    post '/api/v1/mcp/get_financial_summary',
         params: { 
           timeframe: 'recent', 
           categories: ['savings', 'investments', 'spending']
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_not_nil result['summary']
    
    # Should have investment section if data exists
    summary = result['summary']
    assert_not_nil summary['total_balance']
  end

  test "requires authentication" do
    post '/api/v1/mcp/get_financial_summary',
         params: { timeframe: 'recent' }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    assert_response :unauthorized
  end

  test "requires JSON content type" do
    post '/api/v1/mcp/get_financial_summary',
         params: { timeframe: 'recent' },
         headers: { 
           'Authorization' => @auth_headers['Authorization'],
           'Content-Type' => 'text/plain'
         }

    assert_response :unsupported_media_type
  end

  test "suggests relevant next actions" do
    post '/api/v1/mcp/get_financial_summary',
         params: { timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    suggested_actions = json_response['suggested_next_actions']
    assert_not_empty suggested_actions
    assert_includes suggested_actions, 'analyze_spending_pattern'
  end
end
