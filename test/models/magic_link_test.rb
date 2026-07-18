require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "code@example.com")
  end

  test "consume destroys the code so it cannot be reused" do
    link = @user.magic_links.create!
    assert_equal link.code, MagicLink.consume(link.code).code
    assert_nil MagicLink.consume(link.code)
  end

  test "expired codes are not consumable" do
    link = @user.magic_links.create!
    link.update!(expires_at: 1.minute.ago)
    assert_nil MagicLink.consume(link.code)
  end

  test "cleanup deletes stale codes only" do
    active = @user.magic_links.create!
    stale = @user.magic_links.create!
    stale.update!(expires_at: 1.minute.ago)

    MagicLink.cleanup

    assert MagicLink.exists?(active.id)
    assert_not MagicLink.exists?(stale.id)
  end

  test "Code.sanitize maps ambiguous characters and strips invalid ones" do
    assert_equal "011", MagicLink::Code.sanitize("oil")
    assert_equal "AB2", MagicLink::Code.sanitize("a b-2!")
  end

  test "codes are unique on collision" do
    link = @user.magic_links.create!
    assert link.code.present?
    assert_equal MagicLink::CODE_LENGTH, link.code.length
  end
end
