require "test_helper"

class Sessy::Saas::SetupNudgeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "first run nudges every account stalled for two days or more, later runs only the newly stalled" do
    one_day = stalled_account("One Day", approved_at: 1.day.ago)
    three_days = stalled_account("Three Days", approved_at: 3.days.ago)
    thirty_days = stalled_account("Thirty Days", approved_at: 30.days.ago)

    assert_enqueued_emails 2 do
      Sessy::Saas::SetupNudge.deliver_due
    end
    assert_enqueued_email_with Sessy::Saas::SetupNudgeMailer, :nudge, args: [ three_days ]
    assert_enqueued_email_with Sessy::Saas::SetupNudgeMailer, :nudge, args: [ thirty_days ]
    assert_not_nil three_days.reload.setup_nudge_sent_at
    assert_not_nil thirty_days.reload.setup_nudge_sent_at
    assert_nil one_day.reload.setup_nudge_sent_at

    travel 1.day + 1.minute do
      assert_enqueued_emails 1 do
        Sessy::Saas::SetupNudge.deliver_due
      end
      assert_enqueued_email_with Sessy::Saas::SetupNudgeMailer, :nudge, args: [ one_day ]
      assert_not_nil one_day.reload.setup_nudge_sent_at
    end
  end

  test "an account with any source that received an event is not eligible" do
    account = stalled_account("Receiving", approved_at: 5.days.ago)
    account.sources.create!(name: "Staging")
    account.sources.create!(name: "Production", first_event_at: 1.day.ago)

    assert_not_includes Sessy::Saas::SetupNudge.eligible_accounts, account
  end

  test "the instance account and unapproved accounts are never eligible" do
    Account.instance.update!(approved_at: 10.days.ago)
    pending = Account.create!(name: "Pending", retention_days: 30)
    pending.memberships.create!(user: User.create!(email_address: "pending@example.com"), role: "owner")

    assert_empty Sessy::Saas::SetupNudge.eligible_accounts
  end

  test "an already nudged account is skipped" do
    account = stalled_account("Nudged", approved_at: 9.days.ago, setup_nudge_sent_at: 7.days.ago)

    assert_no_enqueued_emails do
      Sessy::Saas::SetupNudge.deliver_due
    end
    assert_not_includes Sessy::Saas::SetupNudge.eligible_accounts, account
  end

  test "variant follows the account's stall point" do
    account = stalled_account("Variants", approved_at: 3.days.ago)
    assert_equal :no_source, Sessy::Saas::SetupNudge.variant_for(account)

    source = account.sources.create!(name: "Production")
    assert_equal :no_subscription, Sessy::Saas::SetupNudge.variant_for(account.reload)

    source.update!(subscribed_at: 1.day.ago)
    assert_equal :no_event, Sessy::Saas::SetupNudge.variant_for(account.reload)
  end

  test "an account with two users gets one mail addressed to both and is stamped once" do
    account = stalled_account("Team", approved_at: 3.days.ago)
    account.memberships.create!(user: User.create!(email_address: "second@example.com"), role: "member")

    assert_enqueued_emails 1 do
      Sessy::Saas::SetupNudge.deliver_due
    end
    assert_enqueued_email_with Sessy::Saas::SetupNudgeMailer, :nudge, args: [ account ]

    stamped_at = account.reload.setup_nudge_sent_at
    assert_not_nil stamped_at

    travel 2.hours do
      assert_no_enqueued_emails { Sessy::Saas::SetupNudge.deliver_due }
    end
    assert_equal stamped_at, account.reload.setup_nudge_sent_at
  end

  test "a failed enqueue after the claim leaves the account stamped so it is never retried" do
    account = stalled_account("Unlucky", approved_at: 3.days.ago)

    with_failing_mailer do
      assert_raises(IOError) { Sessy::Saas::SetupNudge.deliver_due }
    end
    assert_not_nil account.reload.setup_nudge_sent_at

    assert_no_enqueued_emails do
      Sessy::Saas::SetupNudge.deliver_due
    end
  end

  test "two runs working from the same eligible set email each account once" do
    first = stalled_account("First", approved_at: 3.days.ago)
    second = stalled_account("Second", approved_at: 4.days.ago)

    # Run B loaded its candidates before run A stamped anything, then runs
    # after A finished — the interleaving a deploy-time overlap produces.
    stale_candidates = Sessy::Saas::SetupNudge.eligible_accounts.to_a
    assert_equal [ first, second ].sort, stale_candidates.sort

    assert_enqueued_emails 2 do
      Sessy::Saas::SetupNudge.deliver_due
    end

    assert_no_enqueued_emails do
      stale_candidates.each { |account| assert_not Sessy::Saas::SetupNudge.deliver(account) }
    end
  end

  test "claim stamps once and reports whether this caller won" do
    account = stalled_account("Claimed", approved_at: 3.days.ago)

    assert Sessy::Saas::SetupNudge.claim(account)
    assert_not Sessy::Saas::SetupNudge.claim(account)
    assert_not_nil account.reload.setup_nudge_sent_at
  end

  private

  # Mailer actions resolve through ActionMailer::Base.method_missing, so the
  # override is a real singleton method and removing it restores the original.
  def with_failing_mailer
    Sessy::Saas::SetupNudgeMailer.define_singleton_method(:nudge) { |*| raise IOError, "queue unavailable" }
    yield
  ensure
    Sessy::Saas::SetupNudgeMailer.singleton_class.remove_method(:nudge)
  end

  def stalled_account(name, approved_at:, setup_nudge_sent_at: nil)
    account = Account.create!(name: name, retention_days: 30, approved_at: approved_at, setup_nudge_sent_at: setup_nudge_sent_at)
    account.memberships.create!(user: User.create!(email_address: "#{name.parameterize}@example.com"), role: "owner")
    account
  end
end
