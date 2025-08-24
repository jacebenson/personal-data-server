require 'test_helper'

class EntertainmentControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:user_one)
    sign_in @user
  end

  test "should get entertainment index" do
    get entertainment_path
    assert_response :success
    assert_select 'h1', 'Entertainment Dashboard'
  end

  test "should get goodreads upload form" do
    get goodreads_entertainment_index_path
    assert_response :success
    assert_select 'h1', '📚 Upload Goodreads Library'
  end

  test "should get goodreads view when no data" do
    get view_goodreads_entertainment_index_path
    assert_response :success
    assert_select 'h1', '📚 Goodreads Library'
    assert_select 'h3', 'No books found'
  end

  test "goodreads upload requires file" do
    post upload_goodreads_entertainment_index_path
    assert_redirected_to goodreads_entertainment_index_path
    assert_equal "Please select a file to upload.", flash[:alert]
  end

  test "clear goodreads with no data" do
    delete clear_goodreads_entertainment_index_path
    assert_redirected_to entertainment_path
    assert_includes flash[:notice], "Successfully deleted 0 Goodreads book records"
  end
end
