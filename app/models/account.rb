class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :sources, dependent: :destroy

  # The self-hosted singleton: every OSS install lives inside one instance
  # account that owns all data. Created lazily so fresh schema-loaded installs
  # (which never run migration bodies) still get it. `approved?` is always true
  # for it, so the hosted approval gate never applies to self-hosting.
  def self.instance
    Current.instance_account ||= find_or_create_by!(instance: true) do |account|
      account.name = "Sessy"
      account.approved_at = Time.current
    end
  end

  def approved?
    approved_at.present?
  end

  def approve!
    update!(approved_at: Time.current)
  end
end
