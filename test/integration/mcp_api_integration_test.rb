# frozen_string_literal: true

require "test_helper"

class McpApiIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Set up HTTP Basic Auth
    @auth_headers = {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email, "password123"),
      "Content-Type" => "application/json"
    }
  end

  teardown do
    User.destroy_all
  end

  test "complete MCP API workflow for person contact search" do
    # Step 1: Search for a person's name
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "John Doe",
           data_types: [ "financial" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    search_response = JSON.parse(response.body)

    # Step 2: Get detailed contact information
    post "/api/v1/mcp/find_person_contact",
         params: {
           name: "John Doe",
           include_history: true
         }.to_json,
         headers: @auth_headers

    assert_response :success
    contact_response = JSON.parse(response.body)

    # Step 3: Get conversation history
    post "/api/v1/mcp/get_conversation_history",
         params: {
           person_name: "John Doe",
           timeframe: "recent"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    conversation_response = JSON.parse(response.body)

    # Verify all responses have proper MCP format
    [ search_response, contact_response, conversation_response ].each do |response|
      assert_equal true, response["success"]
      assert_not_nil response["action"]
      assert_not_nil response["result"]
      assert_not_nil response["context"]
      assert_not_nil response["suggested_next_actions"]
      assert_not_nil response["timestamp"]
    end
  end

  test "complete MCP API workflow for financial analysis" do
    # Step 1: Get financial summary
    post "/api/v1/mcp/get_financial_summary",
         params: {
           timeframe: "recent",
           include_forecasts: true
         }.to_json,
         headers: @auth_headers

    assert_response :success
    summary_response = JSON.parse(response.body)

    # Step 2: Analyze spending patterns
    post "/api/v1/mcp/analyze_spending_pattern",
         params: {
           category: "dining",
           timeframe: "last month"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    spending_response = JSON.parse(response.body)

    # Step 3: Calculate savings potential
    post "/api/v1/mcp/calculate_savings_potential",
         params: {
           timeframe: "recent",
           focus_categories: [ "subscriptions", "dining" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    savings_response = JSON.parse(response.body)

    # Verify all responses have proper MCP format
    [ summary_response, spending_response, savings_response ].each do |response|
      assert_equal true, response["success"]
      assert_not_nil response["action"]
      assert_not_nil response["result"]
      assert_not_nil response["context"]
      assert_not_nil response["suggested_next_actions"]
      assert_not_nil response["timestamp"]
    end
  end

  test "complete MCP API workflow for content discovery" do
    # Step 1: Discover content recommendations
    post "/api/v1/mcp/discover_content_recommendations",
         params: {
           content_type: "books",
           mood: "learning",
           timeframe: "recent"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    recommendations_response = JSON.parse(response.body)

    # Step 2: Find favorite media
    post "/api/v1/mcp/find_favorite_media",
         params: {
           media_type: "videos",
           timeframe: "last year",
           sort_by: "rating"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    favorites_response = JSON.parse(response.body)

    # Verify both responses have proper MCP format
    [ recommendations_response, favorites_response ].each do |response|
      assert_equal true, response["success"]
      assert_not_nil response["action"]
      assert_not_nil response["result"]
      assert_not_nil response["context"]
      assert_not_nil response["suggested_next_actions"]
      assert_not_nil response["timestamp"]
    end
  end

  test "complete MCP API workflow for health analysis" do
    # Step 1: Analyze health trends
    post "/api/v1/mcp/analyze_health_trends",
         params: {
           metrics: [ "weight", "sleep", "activity" ],
           timeframe: "last 3 months",
           include_recommendations: true
         }.to_json,
         headers: @auth_headers

    assert_response :success
    health_response = JSON.parse(response.body)

    assert_equal true, health_response["success"]
    assert_equal "analyze_health_trends", health_response["action"]
    assert_not_nil health_response["result"]

    result = health_response["result"]
    assert_equal [ "weight", "sleep", "activity" ], result["metrics"]
    assert_equal true, result["include_recommendations"]
  end

  test "MCP API error handling across different endpoints" do
    endpoints_and_invalid_params = [
      [ "/api/v1/mcp/search_all_data", {} ],  # Missing query
      [ "/api/v1/mcp/find_person_contact", {} ],  # Missing name
      [ "/api/v1/mcp/find_recent_mentions", {} ],  # Missing term
      [ "/api/v1/mcp/get_conversation_history", {} ]  # Missing person_name
    ]

    endpoints_and_invalid_params.each do |endpoint, params|
      post endpoint,
           params: params.to_json,
           headers: @auth_headers

      assert_response :bad_request
      json_response = JSON.parse(response.body)

      assert_equal false, json_response["success"]
      assert_not_nil json_response["error"]
      assert_not_nil json_response["action"]
      assert_not_nil json_response["timestamp"]
    end
  end

  test "MCP API authentication across all endpoints" do
    endpoints = [
      "/api/v1/mcp/search_all_data",
      "/api/v1/mcp/find_person_contact",
      "/api/v1/mcp/get_financial_summary",
      "/api/v1/mcp/find_recent_mentions",
      "/api/v1/mcp/analyze_spending_pattern",
      "/api/v1/mcp/get_conversation_history",
      "/api/v1/mcp/calculate_savings_potential",
      "/api/v1/mcp/discover_content_recommendations",
      "/api/v1/mcp/analyze_health_trends",
      "/api/v1/mcp/find_favorite_media"
    ]

    endpoints.each do |endpoint|
      post endpoint,
           params: { query: "test" }.to_json,
           headers: { "Content-Type" => "application/json" }  # No auth

      assert_response :unauthorized
    end
  end

  test "MCP API content type validation across all endpoints" do
    endpoints = [
      "/api/v1/mcp/search_all_data",
      "/api/v1/mcp/find_person_contact",
      "/api/v1/mcp/get_financial_summary"
    ]

    endpoints.each do |endpoint|
      post endpoint,
           params: { query: "test" },  # Not JSON
           headers: {
             "Authorization" => @auth_headers["Authorization"],
             "Content-Type" => "text/plain"
           }

      assert_response :unsupported_media_type
    end
  end

  test "MCP API suggested actions create valid workflows" do
    # Start with a search
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "John Doe",
           data_types: [ "financial" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    search_response = JSON.parse(response.body)

    suggested_actions = search_response["suggested_next_actions"]
    assert_not_empty suggested_actions

    # Verify suggested actions include relevant follow-up endpoints
    assert_includes suggested_actions, "find_person_contact"
  end

  test "MCP API timeframe consistency across endpoints" do
    timeframes = [ "recent", "last week", "last month", "this year" ]

    timeframes.each do |timeframe|
      # Test with search endpoint
      post "/api/v1/mcp/search_all_data",
           params: {
             query: "test",
             timeframe: timeframe
           }.to_json,
           headers: @auth_headers

      assert_response :success
      response_data = JSON.parse(response.body)
      assert_equal timeframe, response_data["result"]["timeframe"]

      # Test with financial endpoint
      post "/api/v1/mcp/get_financial_summary",
           params: { timeframe: timeframe }.to_json,
           headers: @auth_headers

      assert_response :success
      response_data = JSON.parse(response.body)
      assert_equal timeframe, response_data["result"]["timeframe"]
    end
  end

  test "MCP API performance with multiple concurrent requests" do
    threads = []
    results = []

    # Simulate multiple concurrent requests
    5.times do |i|
      threads << Thread.new do
        post "/api/v1/mcp/search_all_data",
             params: { query: "test#{i}" }.to_json,
             headers: @auth_headers

        results << {
          status: response.status,
          thread_id: i,
          response_time: Time.current
        }
      end
    end

    threads.each(&:join)

    # All requests should succeed
    results.each do |result|
      assert_equal 200, result[:status]
    end
  end
end
