require "test_helper"

class Sessy::Saas::ClaimTest < ActiveSupport::TestCase
  test "attaches an owner membership to the instance account without touching sources" do
    source_ids = Account.instance.sources.pluck(:id).sort

    account = Sessy::Saas::Claim.run("owner@example.com")

    assert account.instance?
    assert account.approved?
    assert_equal "owner", account.memberships.find_by(user: User.find_by(email_address: "owner@example.com")).role
    assert_equal source_ids, account.sources.pluck(:id).sort
  end

  test "is idempotent and reuses an existing user" do
    User.create!(email_address: "owner@example.com")

    assert_difference -> { User.count }, 0 do
      2.times { Sessy::Saas::Claim.run("owner@example.com") }
    end
    assert_equal 1, Account.instance.memberships.count
  end
end
