# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/mcp_base_test"

class Api::V1::Mcp::SearchControllerTest < McpBaseTest
  test "search_all_data returns proper MCP format" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "test search",
           timeframe: "recent",
           data_types: [ "financial" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_mcp_response_format(json_response, "search_all_data")

    # Check result structure
    result = json_response["result"]
    assert_not_nil result["query"]
    assert_not_nil result["timeframe"]
    assert_not_nil result["data_types"]
    assert_not_nil result["total_matches"]
    assert_not_nil result["results"]
  end

  test "search_all_data handles missing query parameter" do
    post "/api/v1/mcp/search_all_data",
         params: { timeframe: "recent" }.to_json,
         headers: @auth_headers

    assert_response :bad_request
    json_response = JSON.parse(response.body)

    assert_mcp_error_format(json_response)
    assert_includes json_response["error"], "query"
  end

  test "search_all_data uses default parameters when not specified" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "test" }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal "test", result["query"]
    assert_not_nil result["timeframe"]
    assert_not_nil result["data_types"]
  end

  test "search_all_data handles specific data types" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "test",
           data_types: [ "financial", "health" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal [ "financial", "health" ], result["data_types"]
  end

  test "search_all_data handles timeframe parsing" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "test",
           timeframe: "last month"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal "last month", result["timeframe"]
  end

  test "search_all_data includes results by data type" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "test",
           data_types: [ "financial", "health", "calendar" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    results = result["results"]

    # Should have keys for each data type (even if empty)
    assert_not_nil results["financial"]
    assert_not_nil results["health"]
    assert_not_nil results["calendar"]
  end

  test "search_all_data provides meaningful context" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "important document" }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_empty json_response["context"]
    context = json_response["context"].downcase
    assert_includes context, "search"
  end

  test "search_all_data suggests relevant next actions" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "meeting" }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    suggested_actions = json_response["suggested_next_actions"]
    assert_not_empty suggested_actions
    assert suggested_actions.is_a?(Array)
  end

  test "search_all_data handles empty results gracefully" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "nonexistent_unique_term_12345" }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal 0, result["total_matches"]
    assert_not_nil result["results"]
  end

  test "requires authentication" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "test" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  test "requires JSON content type" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "test" },
         headers: {
           "Authorization" => @auth_headers["Authorization"],
           "Content-Type" => "text/plain"
         }

    assert_response :unsupported_media_type
  end

  test "handles special characters in search query" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "test@example.com & special-chars!" }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal "test@example.com & special-chars!", result["query"]
  end

  test "respects limit parameter" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "test",
           limit: 5
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal 5, result["limit"]
  end

  test "handles case insensitive search" do
    post "/api/v1/mcp/search_all_data",
         params: { query: "TEST" }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)

    result = json_response["result"]
    assert_equal "TEST", result["query"]
    # The search should work regardless of case
    assert_not_nil result["results"]
  end
end
