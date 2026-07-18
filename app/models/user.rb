class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  # Core only mints the record; the hosted engine owns delivery (its controllers
  # send the code mailer). OSS never sends email.
  def mint_magic_link(purpose: :sign_in)
    magic_links.create!(purpose: purpose)
  end
end
