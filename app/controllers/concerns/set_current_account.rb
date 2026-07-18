module SetCurrentAccount
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account
  end

  private

  # OSS resolves to the instance account. Runs independently of the
  # Authentication concern, whose early return (unconfigured HTTP auth) would
  # otherwise skip it. The hosted engine overrides this to resolve the account
  # from the signed-in user's membership.
  def set_current_account
    Current.account = Account.instance
  end
end
