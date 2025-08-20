require 'test_helper'

class DashboardEmailSectionTest < ActionView::TestCase
  include Rails.application.routes.url_helpers

  def setup
    @user = users(:one) # Assuming you have user fixtures
  end

  test "email section renders without errors when emails exist" do
    # Simulate current_user being available
    def current_user
      @user
    end

    # Create a mock email for testing
    email = EmailMessage.new(
      id: 1,
      message_id: "test@example.com",
      received_date: 1.day.ago,
      sender_email: "test@sender.com",
      sender_name: "Test Sender",
      subject: "Test Subject",
      content: "Test content for the email",
      message_size: 1024,
      attachments_count: 0,
      user: @user
    )

    # Mock the relationship to return our test emails
    @user.define_singleton_method(:email_messages) do
      scope = EmailMessage.where(id: [1])
      scope.define_singleton_method(:where) { |*args| scope }
      scope.define_singleton_method(:recent) { scope }
      scope.define_singleton_method(:limit) { |num| [email] }
      scope.define_singleton_method(:count) { 1 }
      scope
    end

    # Render the partial
    output = render partial: 'emails/shared/email_section'
    
    # Check that it contains expected elements
    assert_includes output, "Recent Emails"
    assert_includes output, "Test Sender"
    assert_includes output, "Test Subject"
    assert_includes output, "Last 2 weeks"
  end

  test "email section shows no emails state when no emails exist" do
    # Simulate current_user being available
    def current_user
      @user
    end

    # Mock empty email messages
    @user.define_singleton_method(:email_messages) do
      scope = EmailMessage.none
      scope.define_singleton_method(:where) { |*args| scope }
      scope.define_singleton_method(:recent) { scope }
      scope.define_singleton_method(:limit) { |num| [] }
      scope.define_singleton_method(:count) { 0 }
      scope
    end

    # Render the partial
    output = render partial: 'emails/shared/email_section'
    
    # Check that it shows empty state
    assert_includes output, "No recent emails found"
    assert_includes output, "Import Emails"
  end
end
