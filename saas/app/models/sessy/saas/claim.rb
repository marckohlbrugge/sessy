# Hosted launch claim: attach an owner to the instance account, which already
# owns the migrated launch data (U1 backfill). Idempotent — safe to re-run.
module Sessy::Saas::Claim
  def self.run(email)
    account = Account.instance
    account.approve! unless account.approved?

    user = User.find_or_create_by!(email_address: email)
    account.memberships.find_or_create_by!(user: user) { |membership| membership.role = "owner" }

    account
  end
end
