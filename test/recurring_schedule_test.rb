require "test_helper"

# Solid Queue evaluates `command:` entries as Ruby. Hosted-only entries guard
# on Sessy.saas? so the engine class they name is never touched in OSS.
class RecurringScheduleTest < ActiveSupport::TestCase
  test "setup nudge command is a no-op when the saas engine is absent" do
    command = recurring_schedule.dig("production", "setup_nudge", "command")
    assert_includes command, "Sessy.saas? &&"

    result = nil
    assert_nothing_raised { result = eval(command) } # rubocop:disable Security/Eval
    assert_equal false, result unless Sessy.saas?
  end

  private

  def recurring_schedule
    YAML.load_file(Rails.root.join("config/recurring.yml"))
  end
end
