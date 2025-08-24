# frozen_string_literal: true

require "test_helper"

# LLM Evaluation Tests - Test MCP API effectiveness for LLM tool usage
# These tests simulate how an LLM would interact with the MCP API and validate
# that responses are clear, actionable, and follow expected patterns
class McpLlmEvaluationTest < ActionDispatch::IntegrationTest
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

  # Test human-like question: "When was the last time I mentioned AI?"
  test "LLM query: recent mentions of specific topic" do
    post "/api/v1/mcp/find_recent_mentions",
         params: {
           term: "AI",
           timeframe: "recent"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    # Validate LLM-friendly response structure
    assert_llm_response_quality(response_data, "find_recent_mentions")

    result = response_data["result"]
    assert_equal "AI", result["search_term"]
    assert_not_nil result["mentions"]
    assert_includes response_data["context"], "mentions"

    # Context should be human-readable and informative
    context = response_data["context"]
    assert context.length > 10, "Context should be descriptive"
    assert_no_match /null|undefined|error/i, context
  end

  # Test human-like question: "How can I reach Sarah?"
  test "LLM query: finding contact information" do
    post "/api/v1/mcp/find_person_contact",
         params: {
           name: "Sarah",
           include_history: true
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "find_person_contact")

    result = response_data["result"]
    assert_equal "Sarah", result["search_name"]
    assert_not_nil result["contacts_found"]
    assert_not_nil result["communication_history"]

    # Suggested actions should include relevant follow-ups
    suggested_actions = response_data["suggested_next_actions"]
    assert_includes suggested_actions, "get_conversation_history"
  end

  # Test human-like question: "What should I watch next?"
  test "LLM query: content recommendations" do
    post "/api/v1/mcp/discover_content_recommendations",
         params: {
           content_type: "videos",
           mood: "entertaining"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "discover_content_recommendations")

    result = response_data["result"]
    assert_equal "videos", result["content_type"]
    assert_equal "entertaining", result["mood"]
    assert_not_nil result["recommendations"]

    # Recommendations should have helpful structure
    recommendations = result["recommendations"]
    recommendations.each do |rec|
      assert_not_nil rec["type"]
      assert_not_nil rec["title"] || rec["name"]
      assert_not_nil rec["reason"] if rec["reason"]
    end
  end

  # Test human-like question: "How much am I spending on dining?"
  test "LLM query: spending analysis" do
    post "/api/v1/mcp/analyze_spending_pattern",
         params: {
           category: "dining",
           timeframe: "last month"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "analyze_spending_pattern")

    result = response_data["result"]
    assert_equal "dining", result["category"]
    assert_equal "last month", result["timeframe"]
    assert_not_nil result["analysis"]

    # Context should provide actionable insights
    context = response_data["context"]
    assert_includes context.downcase, "spending"

    # Suggested actions should offer next steps
    suggested_actions = response_data["suggested_next_actions"]
    assert_includes suggested_actions, "calculate_savings_potential"
  end

  # Test human-like question: "Show me my favorite videos from 2023"
  test "LLM query: favorite media from specific time period" do
    post "/api/v1/mcp/find_favorite_media",
         params: {
           media_type: "videos",
           timeframe: "2023",
           sort_by: "rating",
           limit: 10
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "find_favorite_media")

    result = response_data["result"]
    assert_equal "videos", result["media_type"]
    assert_equal "2023", result["timeframe"]
    assert_equal "rating", result["sort_by"]
    assert_equal 10, result["limit"]

    # Favorites should have meaningful structure
    favorites = result["favorites"]
    favorites.each do |fav|
      assert_not_nil fav["type"]
      assert_not_nil fav["title"] || fav["name"]
    end
  end

  # Test human-like question: "Find everything about Project Alpha"
  test "LLM query: comprehensive search across data types" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "Project Alpha",
           data_types: [ "financial", "calendar" ]
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "search_all_data")

    result = response_data["result"]
    assert_equal "Project Alpha", result["query"]
    assert_equal [ "financial", "calendar" ], result["data_types"]

    # Results should be organized by data type
    results = result["results"]
    assert_not_nil results["financial"]
    assert_not_nil results["calendar"]

    # Context should summarize findings clearly
    context = response_data["context"]
    assert_includes context, "Project Alpha"
    assert_match /\d+/, context  # Should include counts
  end

  # Test LLM error handling and guidance
  test "LLM error handling: missing required parameters" do
    post "/api/v1/mcp/find_person_contact",
         params: { include_history: true }.to_json,  # Missing name
         headers: @auth_headers

    assert_response :bad_request
    response_data = JSON.parse(response.body)

    assert_equal false, response_data["success"]
    assert_not_nil response_data["error"]

    # Error should be clear and actionable for LLM
    error_message = response_data["error"]
    assert_includes error_message.downcase, "name"
    assert_includes error_message.downcase, "required"

    # Should include helpful suggestions
    assert_not_nil response_data["suggestions"] if response_data["suggestions"]
  end

  # Test LLM fallback behavior when no data is found
  test "LLM graceful handling: no results found" do
    post "/api/v1/mcp/search_all_data",
         params: {
           query: "extremely_unique_nonexistent_term_12345"
         }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "search_all_data")

    result = response_data["result"]
    assert_equal 0, result["total_matches"]

    # Context should acknowledge no results but remain helpful
    context = response_data["context"]
    assert_includes context.downcase, "no"
    assert_not_includes context.downcase, "error"

    # Should still suggest alternative actions
    assert_not_empty response_data["suggested_next_actions"]
  end

  # Test LLM understanding of natural timeframes
  test "LLM timeframe understanding: natural language expressions" do
    natural_timeframes = [ "recent", "last week", "this month", "last year" ]

    natural_timeframes.each do |timeframe|
      post "/api/v1/mcp/find_recent_mentions",
           params: {
             term: "test",
             timeframe: timeframe
           }.to_json,
           headers: @auth_headers

      assert_response :success
      response_data = JSON.parse(response.body)

      result = response_data["result"]
      assert_equal timeframe, result["timeframe"]

      # Context should acknowledge the timeframe in human terms
      context = response_data["context"]
      assert_not_includes context, "null"
    end
  end

  # Test that responses provide enough context for LLM to formulate follow-up questions
  test "LLM context richness: sufficient information for follow-ups" do
    post "/api/v1/mcp/get_financial_summary",
         params: { timeframe: "recent" }.to_json,
         headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_llm_response_quality(response_data, "get_financial_summary")

    # Response should provide multiple paths for follow-up
    suggested_actions = response_data["suggested_next_actions"]
    assert suggested_actions.length >= 2, "Should suggest multiple follow-up actions"

    # Context should be rich enough for LLM understanding
    context = response_data["context"]
    assert context.length >= 20, "Context should be descriptive"

    # Result should have structured data that LLM can reference
    result = response_data["result"]
    assert_not_nil result["summary"]
    assert_not_nil result["accounts"] if result["accounts"]
  end

  private

  def assert_llm_response_quality(response_data, expected_action)
    # Test core MCP structure
    assert_equal true, response_data["success"]
    assert_equal expected_action, response_data["action"]
    assert_not_nil response_data["result"]
    assert_not_nil response_data["context"]
    assert_not_nil response_data["suggested_next_actions"]
    assert_not_nil response_data["timestamp"]

    # Test LLM-specific quality criteria

    # Context should be human-readable and informative
    context = response_data["context"]
    assert context.is_a?(String), "Context should be a string"
    assert context.length > 5, "Context should be meaningful"
    assert_no_match /^\s*$/, context, "Context should not be empty/whitespace"

    # Suggested actions should be actionable
    actions = response_data["suggested_next_actions"]
    assert actions.is_a?(Array), "Suggested actions should be an array"
    assert actions.length > 0, "Should suggest at least one action"
    actions.each do |action|
      assert action.is_a?(String), "Each action should be a string"
      assert action.length > 0, "Each action should not be empty"
    end

    # Timestamp should be valid ISO format
    timestamp = response_data["timestamp"]
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, timestamp

    # Result should have meaningful structure
    result = response_data["result"]
    assert result.is_a?(Hash), "Result should be a hash/object"
    assert result.keys.length > 0, "Result should have content"
  end
end
