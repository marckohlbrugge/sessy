require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is normalized" do
    user = User.create!(email_address: "  Person@Example.COM ")
    assert_equal "person@example.com", user.email_address
  end

  test "email is unique" do
    User.create!(email_address: "dup@example.com")
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(email_address: "dup@example.com") }
  end

  test "mint_magic_link creates a code with the given purpose" do
    user = User.create!(email_address: "mint@example.com")
    link = user.mint_magic_link(purpose: :sign_up)
    assert link.for_sign_up?
    assert link.persisted?
  end

  test "membership uniqueness scoped to account" do
    user = User.create!(email_address: "member@example.com")
    account = Account.instance
    account.memberships.create!(user: user)
    dup = account.memberships.build(user: user)
    assert_not dup.valid?
  end
end
