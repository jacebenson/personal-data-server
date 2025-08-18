# frozen_string_literal: true

require 'test_helper'

# Base class for MCP API tests that avoids fixture loading issues
class McpBaseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = create_test_user
    @auth_headers = { 
      'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email, 'password123'),
      'Content-Type' => 'application/json'
    }
  end

  def teardown
    User.destroy_all if defined?(User)
  end

  private

  def create_test_user
    User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  rescue => e
    # If User model doesn't exist or has different attributes, create a mock
    puts "Warning: Could not create User: #{e.message}"
    OpenStruct.new(email: 'test@example.com', id: 1)
  end

  # Helper method to assert MCP response format
  def assert_mcp_response_format(response_data, expected_action)
    assert_equal true, response_data['success']
    assert_equal expected_action, response_data['action']
    assert_not_nil response_data['result']
    assert_not_nil response_data['context']
    assert_not_nil response_data['suggested_next_actions']
    assert_not_nil response_data['timestamp']
  end

  # Helper method to assert MCP error format
  def assert_mcp_error_format(response_data)
    assert_equal false, response_data['success']
    assert_not_nil response_data['error']
    assert_not_nil response_data['action']
    assert_not_nil response_data['timestamp']
  end
end
