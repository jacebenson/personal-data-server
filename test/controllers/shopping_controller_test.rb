require "test_helper"

class ShoppingControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get shopping_index_path
    assert_response :success
    assert_select "h2", "Shopping Data Management"
  end

  test "should get upload" do
    get upload_shopping_index_path
    assert_response :success
    assert_select "h2", "Upload Amazon Orders"
  end

  test "should get upload_digital" do
    get upload_digital_shopping_index_path
    assert_response :success
    assert_select "h2", "Upload Amazon Digital Orders"
  end

  test "should get view_orders with no orders" do
    get view_orders_shopping_index_path
    assert_response :success
    assert_select "h3", "No orders found"
  end

  test "should get view_orders with orders" do
    # Create a test order
    AmazonOrder.create!(
      user: @user,
      order_id: "123-4567890-1234567",
      order_date: Date.current,
      product_name: "Test Product",
      order_type: "retail",
      total_owed: 29.99,
      asin: "B01234567X"
    )

    get view_orders_shopping_index_path
    assert_response :success
    assert_select "td", "Test Product"
    assert_select "a[href*='amazon.com/dp/B01234567X']"
  end

  test "should handle pagination" do
    # Create multiple orders to test pagination
    25.times do |i|
      AmazonOrder.create!(
        user: @user,
        order_id: "123-4567890-123456#{i}",
        order_date: Date.current - i.days,
        product_name: "Test Product #{i}",
        order_type: "retail",
        total_owed: 10.00 + i
      )
    end

    get view_orders_shopping_index_path
    assert_response :success
    assert_select "div", /Showing.*of.*orders/

    # Test second page
    get view_orders_shopping_index_path(page: 2)
    assert_response :success
  end

  test "should show digital order with subscription badge" do
    AmazonOrder.create!(
      user: @user,
      order_id: "123-4567890-1234567",
      order_date: Date.current,
      product_name: "Digital Subscription",
      order_type: "digital",
      total_owed: 9.99,
      subscription_info: "Monthly",
      publisher: "Amazon.com Services, Inc"
    )

    get view_orders_shopping_index_path
    assert_response :success
    assert_select "span", /Subscription/
    assert_select "span", /Digital/
  end
end
