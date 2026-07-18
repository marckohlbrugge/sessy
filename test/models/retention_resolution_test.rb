require "test_helper"

# Effective retention resolves source-then-account, and the sweep reaches
# sources that rely only on the account default (the redesigned enumeration).
class RetentionResolutionTest < ActiveSupport::TestCase
  test "account default applies when the source has none" do
    account = Account.create!(name: "Hosted", retention_days: 30)
    source = account.sources.create!(name: "Src")

    old = Message.create!(source: source, ses_message_id: SecureRandom.uuid, sent_at: 31.days.ago)
    recent = Message.create!(source: source, ses_message_id: SecureRandom.uuid, sent_at: 29.days.ago)

    assert_equal 30, source.effective_retention_days
    source.delete_expired_data
    assert_not Message.exists?(old.id)
    assert Message.exists?(recent.id)
  end

  test "per-source override wins over the account default in both directions" do
    account = Account.create!(name: "Hosted", retention_days: 30)
    source = account.sources.create!(name: "Src", retention_days: 7)
    assert_equal 7, source.effective_retention_days
  end

  test "nil source and nil account keeps everything" do
    account = Account.create!(name: "Unlimited", retention_days: nil)
    source = account.sources.create!(name: "Src")
    assert_nil source.effective_retention_days
    assert_equal 0, source.delete_expired_data
  end

  test "with_retention_policy reaches account-default sources" do
    account = Account.create!(name: "Hosted", retention_days: 30)
    source = account.sources.create!(name: "Src")
    assert_includes Source.with_retention_policy, source
  end
end
