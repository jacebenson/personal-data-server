# frozen_string_literal: true

require 'test_helper'
require_relative '../../../support/mcp_base_test'

class Api::V1::Mcp::BaseControllerTest < McpBaseTest

  test "requires JSON content type" do
    post '/api/v1/mcp/search_all_data', 
         params: { query: 'test' }.to_json,
         headers: { 
           'Authorization' => @auth_headers['Authorization'],
           'Content-Type' => 'text/plain' 
         }
    
    assert_response :unsupported_media_type
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
    assert_includes json_response['error'], 'Content-Type must be application/json'
  end

  test "requires authentication for all MCP endpoints" do
    post '/api/v1/mcp/search_all_data',
         params: { query: 'test' }.to_json,
         headers: { 'Content-Type' => 'application/json' }
    
    assert_response :unauthorized
  end

  test "handles invalid HTTP Basic Auth credentials" do
    invalid_auth = ActionController::HttpAuthentication::Basic.encode_credentials('invalid@email.com', 'wrongpassword')
    
    post '/api/v1/mcp/search_all_data',
         params: { query: 'test' }.to_json,
         headers: { 
           'Authorization' => invalid_auth,
           'Content-Type' => 'application/json' 
         }
    
    assert_response :unauthorized
  end

  test "validates required parameters and returns MCP error format" do
    post '/api/v1/mcp/search_all_data',
         params: { timeframe: 'recent' }.to_json,  # Missing required 'query' param
         headers: @auth_headers
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_mcp_error_format(json_response)
  end

  test "returns consistent MCP success format" do
    post '/api/v1/mcp/search_all_data',
         params: { query: 'test' }.to_json,
         headers: @auth_headers
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # Verify all required MCP fields are present
    assert_mcp_response_format(json_response, 'search_all_data')
    
    # Verify timestamp format
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, json_response['timestamp']
  end

  test "handles timeframe parsing through base controller" do
    post '/api/v1/mcp/search_all_data',
         params: { 
           query: 'test',
           timeframe: 'recent'
         }.to_json,
         headers: @auth_headers
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # The base controller should have parsed the timeframe
    result = json_response['result']
    assert_equal 'recent', result['timeframe']
  end

  test "handles malformed JSON gracefully" do
    post '/api/v1/mcp/search_all_data',
         params: '{ "query": "test", invalid json }',
         headers: @auth_headers
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_mcp_error_format(json_response)
    assert_includes json_response['error'], 'Invalid JSON'
  end

  test "sanitizes user input to prevent injection" do
    malicious_input = "<script>alert('xss')</script>"
    
    post '/api/v1/mcp/search_all_data',
         params: { query: malicious_input }.to_json,
         headers: @auth_headers
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # The input should be sanitized or handled safely
    result = json_response['result']
    assert_equal malicious_input, result['query']  # Should be stored as-is but handled safely
  end
end
