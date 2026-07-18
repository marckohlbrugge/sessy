# Assigns every account-less source to the instance account. Extracted from the
# migration so the backfill logic is unit-testable against legacy-state rows.
module Source::AccountBackfill
  def self.run
    account = Account.instance
    Source.where(account_id: nil).update_all(account_id: account.id)
  end
end
