require "test_helper"
require "rake"

class Sessy::Saas::NotifyPendingTaskTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("saas:notify_pending")
  end

  teardown do
    Rake::Task["saas:notify_pending"].reenable
  end

  test "queues a notification per pending account, skipping approved and memberless ones" do
    pending = Account.create!(name: "Pending's Sessy", retention_days: 30)
    pending.memberships.create!(user: User.create!(email_address: "pending@example.com"), role: "owner")

    approved = Account.create!(name: "Approved's Sessy", retention_days: 30, approved_at: Time.current)
    approved.memberships.create!(user: User.create!(email_address: "approved@example.com"), role: "owner")

    Account.create!(name: "Abandoned's Sessy", retention_days: 30) # no membership

    with_admin_email "admin@example.com" do
      assert_enqueued_email_with Sessy::Saas::AdminMailer, :new_signup, args: [ pending ] do
        Rake::Task["saas:notify_pending"].invoke
      end
      assert_enqueued_emails 1
    end
  end

  private

  def with_admin_email(address)
    original = ENV["ADMIN_EMAIL"]
    ENV["ADMIN_EMAIL"] = address
    yield
  ensure
    original.nil? ? ENV.delete("ADMIN_EMAIL") : ENV["ADMIN_EMAIL"] = original
  end
end
