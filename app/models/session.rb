class Session < ApplicationRecord
  belongs_to :user

  # Sessions expire after this much inactivity; activity slides the window.
  # updated_at doubles as last-active-at (a Session is only ever touched on use).
  INACTIVITY_LIMIT = 30.days

  def expired?
    updated_at < INACTIVITY_LIMIT.ago
  end

  # Extend the idle window, but at most once a day to avoid a write per request.
  def touch_if_stale
    touch if updated_at < 1.day.ago
  end
end
