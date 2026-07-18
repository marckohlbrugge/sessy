require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # These assert OSS UI behavior and run green in both adapter legs. In hosted
  # mode the whole app is behind session auth; the auth and tenant flows are
  # covered by saas/test integration tests, so skip the OSS system suite here
  # rather than plumb a cross-thread session into every case.
  setup do
    skip "OSS system tests run in OSS mode; hosted flows are covered by saas/test" if Sessy.saas?
  end
end
