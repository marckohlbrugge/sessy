class Current < ActiveSupport::CurrentAttributes
  attribute :account
  attribute :user, :session
  # Per-request memo for the lazily-resolved instance account, so OSS mode
  # doesn't hit the database on every Account.instance call.
  attribute :instance_account
end
