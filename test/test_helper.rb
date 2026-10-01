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
  teardown :restore_sns_confirmation_fetcher

  # Stands in for SNS when the webhook controller fetches a SubscribeURL, so
  # no test makes a real outbound request. Restored after each test.
  def stub_sns_confirmation(status: 200, body: "<SubscriptionArn>arn:aws:sns:us-east-1:1:topic:sub</SubscriptionArn>")
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s).new("1.1", status.to_s, "")
    response.body = body
    response.instance_variable_set(:@read, true) # no socket to read from

    @original_sns_confirmation_fetcher ||= SnsSubscriptionConfirmation.fetcher
    SnsSubscriptionConfirmation.fetcher = ->(_uri) { response }
  end

  def restore_sns_confirmation_fetcher
    SnsSubscriptionConfirmation.fetcher = @original_sns_confirmation_fetcher if @original_sns_confirmation_fetcher
  end

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
