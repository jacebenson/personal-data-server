# frozen_string_literal: true

require 'test_helper'

class Api::V1::Mcp::ContentControllerTest < ActionDispatch::IntegrationTest
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

  test "discover_content_recommendations returns proper MCP format" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { 
           content_type: 'books', 
           mood: 'learning',
           timeframe: 'recent',
           based_on: 'reading_history'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'discover_content_recommendations', json_response['action']
    assert_not_nil json_response['result']
    assert_not_nil json_response['context']
    assert_not_nil json_response['suggested_next_actions']
    assert_not_nil json_response['timestamp']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['content_type']
    assert_not_nil result['mood']
    assert_not_nil result['timeframe']
    assert_not_nil result['based_on']
    assert_not_nil result['recommendations']
    assert_not_nil result['recommendation_count']
  end

  test "find_favorite_media returns proper MCP format" do
    post '/api/v1/mcp/find_favorite_media',
         params: { 
           media_type: 'videos', 
           timeframe: '2020',
           sort_by: 'rating',
           limit: 10
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'find_favorite_media', json_response['action']
    assert_not_nil json_response['result']
    
    # Check result structure
    result = json_response['result']
    assert_not_nil result['media_type']
    assert_not_nil result['timeframe']
    assert_not_nil result['sort_by']
    assert_not_nil result['limit']
    assert_not_nil result['favorites']
    assert_not_nil result['total_found']
  end

  test "handles different content types for recommendations" do
    content_types = ['books', 'videos', 'podcasts', 'music']
    
    content_types.each do |content_type|
      post '/api/v1/mcp/discover_content_recommendations',
           params: { 
             content_type: content_type,
             mood: 'relaxing'
           }.to_json,
           headers: @auth_headers

      assert_response :success
      json_response = JSON.parse(response.body)
      
      result = json_response['result']
      assert_equal content_type, result['content_type']
      assert_not_nil result['recommendations']
    end
  end

  test "handles different media types for favorites" do
    media_types = ['videos', 'books', 'podcasts', 'netflix']
    
    media_types.each do |media_type|
      post '/api/v1/mcp/find_favorite_media',
           params: { 
             media_type: media_type,
             timeframe: 'recent'
           }.to_json,
           headers: @auth_headers

      assert_response :success
      json_response = JSON.parse(response.body)
      
      result = json_response['result']
      assert_equal media_type, result['media_type']
      assert_not_nil result['favorites']
    end
  end

  test "handles different moods for recommendations" do
    moods = ['learning', 'relaxing', 'entertaining', 'motivational']
    
    moods.each do |mood|
      post '/api/v1/mcp/discover_content_recommendations',
           params: { 
             content_type: 'books',
             mood: mood
           }.to_json,
           headers: @auth_headers

      assert_response :success
      json_response = JSON.parse(response.body)
      
      result = json_response['result']
      assert_equal mood, result['mood']
      assert_not_nil result['recommendations']
    end
  end

  test "handles different sort options for favorites" do
    sort_options = ['rating', 'recent', 'duration', 'popularity']
    
    sort_options.each do |sort_by|
      post '/api/v1/mcp/find_favorite_media',
           params: { 
             media_type: 'videos',
             sort_by: sort_by
           }.to_json,
           headers: @auth_headers

      assert_response :success
      json_response = JSON.parse(response.body)
      
      result = json_response['result']
      assert_equal sort_by, result['sort_by']
    end
  end

  test "respects limit parameter for favorites" do
    post '/api/v1/mcp/find_favorite_media',
         params: { 
           media_type: 'videos',
           limit: 5
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 5, result['limit']
    
    # Favorites array should respect limit
    favorites = result['favorites']
    assert favorites.length <= 5
  end

  test "handles timeframe parsing for content" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { 
           content_type: 'books',
           timeframe: 'last year'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'last year', result['timeframe']
  end

  test "provides meaningful content context messages" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { 
           content_type: 'podcasts',
           mood: 'learning'
         }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_not_empty json_response['context']
    context = json_response['context'].downcase
    assert_includes context, 'podcast'
  end

  test "handles missing content_type with default" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { mood: 'relaxing' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'books', result['content_type'] # Default
  end

  test "handles missing media_type with default" do
    post '/api/v1/mcp/find_favorite_media',
         params: { timeframe: 'recent' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    result = json_response['result']
    assert_equal 'videos', result['media_type'] # Default
  end

  test "requires authentication" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { content_type: 'books' }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    assert_response :unauthorized
  end

  test "requires JSON content type" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { content_type: 'books' },
         headers: { 
           'Authorization' => @auth_headers['Authorization'],
           'Content-Type' => 'text/plain'
         }

    assert_response :unsupported_media_type
  end

  test "suggests relevant next actions for recommendations" do
    post '/api/v1/mcp/discover_content_recommendations',
         params: { content_type: 'books' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    suggested_actions = json_response['suggested_next_actions']
    assert_not_empty suggested_actions
    assert_includes suggested_actions, 'find_favorite_media'
  end

  test "suggests relevant next actions for favorites" do
    post '/api/v1/mcp/find_favorite_media',
         params: { media_type: 'videos' }.to_json,
         headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    
    suggested_actions = json_response['suggested_next_actions']
    assert_not_empty suggested_actions
    assert_includes suggested_actions, 'discover_content_recommendations'
  end
end
