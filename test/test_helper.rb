ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # Core controller tests run in both editions. OSS needs no session; in SaaS
  # mode every ApplicationController route wants a signed-in account member.
  def sign_in_to(account)
    return unless Sessy.saas?

    user = User.create!(email_address: "owner-#{SecureRandom.hex(4)}@example.com")
    account.memberships.create!(user: user)
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }
  end
end
