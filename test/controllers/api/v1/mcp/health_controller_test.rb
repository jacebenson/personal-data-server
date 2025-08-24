# frozen_string_literal: true

require 'test_helper'

class Api::V1::Mcp::HealthControllerTest < ActionDispatch::IntegrationTest
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

  test "analyze_health_trends returns proper MCP format" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight', 'sleep', 'activity'], 
           timeframe: 'last 3 months',
           include_recommendations: true
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'analyze_health_trends', json_response['action']
    assert_not_nil json_response['result']
    assert_not_nil json_response['context']
    assert_not_nil json_response['suggested_next_actions']
    assert_not_nil json_response['timestamp']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['metrics']
    assert_not_nil result['timeframe']
    assert_not_nil result['include_recommendations']
    assert_not_nil result['trends']
    assert_not_nil result['recommendations']
  end

  test "handles single metric analysis" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight'], 
           timeframe: 'recent'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal ['weight'], result['metrics']
    assert_not_nil result['trends']
  end

  test "handles multiple metrics analysis" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight', 'sleep', 'activity', 'heart_rate'], 
           timeframe: 'last month'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal ['weight', 'sleep', 'activity', 'heart_rate'], result['metrics']
    assert_not_nil result['trends']
    
    # Should have data for each requested metric (even if empty)
    trends = result['trends']
    assert_includes trends.keys, 'weight'
    assert_includes trends.keys, 'sleep'
    assert_includes trends.keys, 'activity'
    assert_includes trends.keys, 'heart_rate'
  end

  test "includes recommendations when requested" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight', 'sleep'], 
           timeframe: 'recent',
           include_recommendations: true
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal true, result['include_recommendations']
    assert_not_nil result['recommendations']
    assert result['recommendations'].is_a?(Array)
  end

  test "excludes recommendations when not requested" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight'], 
           timeframe: 'recent',
           include_recommendations: false
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal false, result['include_recommendations']
    # Should still have recommendations array but it might be empty
    assert_not_nil result['recommendations']
  end

  test "handles different timeframes" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight'], 
           timeframe: 'this year'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'this year', result['timeframe']
  end

  test "provides meaningful health context" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['sleep', 'activity'], 
           timeframe: 'recent'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_not_empty json_response['context']
    context = json_response['context'].downcase
    assert_includes context, 'health'
  end

  test "handles missing metrics parameter gracefully" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    # Should default to common metrics
    result = json_response['result']
    assert_not_nil result['metrics']
    assert_not_empty result['metrics']
  end

  test "requires authentication" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { metrics: ['weight'] }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    assert_response :unauthorized
  end

  test "requires JSON content type" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { metrics: ['weight'] },
         headers: { 
           'Authorization' => @auth_headers['Authorization'],
           'Content-Type' => 'text/plain'
         }

    assert_response :unsupported_media_type
  end

  test "suggests relevant next actions" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight', 'sleep'], 
           timeframe: 'recent'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    suggested_actions = json_response['suggested_next_actions']
    assert_not_empty suggested_actions
    assert suggested_actions.is_a?(Array)
  end

  test "handles empty health data gracefully" do
    post '/api/v1/mcp/analyze_health_trends',
         params: { 
           metrics: ['weight'], 
           timeframe: 'recent'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    # Should still return proper structure even with no data
    result = json_response['result']
    assert_not_nil result['trends']
    assert_not_nil result['recommendations']
  end
end
