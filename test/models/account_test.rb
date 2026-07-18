require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "instance is a lazily created singleton" do
    Account.where(instance: true).destroy_all
    Current.instance_account = nil

    account = Account.instance
    assert account.instance?
    assert account.approved?

    Current.instance_account = nil
    assert_equal account, Account.instance
    assert_equal 1, Account.where(instance: true).count
  end

  test "approved? reflects approved_at" do
    account = Account.new
    assert_not account.approved?
    account.approve!
    assert account.approved?
  end

  test "backfill is idempotent and leaves every source owned by an account" do
    # The account_id NOT NULL constraint prevents reconstructing legacy null
    # state in-test; the migration itself exercises the null->instance path
    # (and the U8 runbook rehearses it end-to-end). Here we prove the callable
    # is a safe no-op once every source already has an account.
    assert_nothing_raised { Source::AccountBackfill.run }
    assert_equal 0, Source.where(account_id: nil).count
  end

  test "new sources default to the instance account" do
    source = Source.create!(name: "Test")
    assert_equal Account.instance, source.account
  end
end
