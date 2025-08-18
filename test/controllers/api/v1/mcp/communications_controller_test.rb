# frozen_string_literal: true

require 'test_helper'

class Api::V1::Mcp::CommunicationsControllerTest < ActionDispatch::IntegrationTest
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

  test "find_person_contact returns proper MCP format" do
    post '/api/v1/mcp/find_person_contact',
         params: { name: 'John Doe', include_history: true }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'find_person_contact', json_response['action']
    assert_not_nil json_response['result']
    assert_not_nil json_response['context']
    assert_not_nil json_response['suggested_next_actions']
    assert_not_nil json_response['timestamp']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['search_name']
    assert_not_nil result['contacts_found']
    assert_not_nil result['communication_history']
  end

  test "find_person_contact handles missing name parameter" do
    post '/api/v1/mcp/find_person_contact',
         params: { include_history: true }.to_json,
         headers: @auth_headers

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_includes json_response['error'], 'name'
  end

  test "find_recent_mentions returns proper MCP format" do
    post '/api/v1/mcp/find_recent_mentions',
         params: { term: 'AI', timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'find_recent_mentions', json_response['action']
    assert_not_nil json_response['result']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['search_term']
    assert_not_nil result['timeframe']
    assert_not_nil result['mentions']
    assert_not_nil result['total_found']
  end

  test "find_recent_mentions handles missing term parameter" do
    post '/api/v1/mcp/find_recent_mentions',
         params: { timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_includes json_response['error'], 'term'
  end

  test "get_conversation_history returns proper MCP format" do
    post '/api/v1/mcp/get_conversation_history',
         params: { person_name: 'Jane Smith', timeframe: 'last month', limit: 10 }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'get_conversation_history', json_response['action']
    assert_not_nil json_response['result']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['person_name']
    assert_not_nil result['timeframe']
    assert_not_nil result['limit']
    assert_not_nil result['conversations']
    assert_not_nil result['total_found']
  end

  test "get_conversation_history handles missing person_name parameter" do
    post '/api/v1/mcp/get_conversation_history',
         params: { timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_includes json_response['error'], 'person_name'
  end

  test "requires authentication for all endpoints" do
    # Test without auth headers
    post '/api/v1/mcp/find_person_contact',
         params: { name: 'John Doe' }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    assert_response :unauthorized
  end

  test "requires JSON content type" do
    post '/api/v1/mcp/find_person_contact',
         params: { name: 'John Doe' },
         headers: { 
           'Authorization' => @auth_headers['Authorization'],
           'Content-Type' => 'text/plain'
         }

    assert_response :unsupported_media_type
  end

  test "handles timeframe parsing correctly" do
    post '/api/v1/mcp/find_recent_mentions',
         params: { term: 'test', timeframe: 'last week' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'last week', result['timeframe']
  end

  test "provides meaningful context messages" do
    post '/api/v1/mcp/find_person_contact',
         params: { name: 'Unknown Person' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_not_empty json_response['context']
    assert_includes json_response['context'].downcase, 'contact'
  end

  test "includes suggested next actions" do
    post '/api/v1/mcp/find_recent_mentions',
         params: { term: 'test' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_not_empty json_response['suggested_next_actions']
    assert json_response['suggested_next_actions'].is_a?(Array)
  end
end
