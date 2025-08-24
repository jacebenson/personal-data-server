ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Don't setup all fixtures automatically - let tests opt in
    # fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
