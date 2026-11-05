# A bounce or complaint rate measured against the levels at which AWS puts an
# SES account under review and may pause its sending. AWS applies these to the
# whole account, so a single source's rate is an early signal, not the verdict.
# https://docs.aws.amazon.com/ses/latest/dg/faqs-enforcement.html
class ReputationRate
  THRESHOLDS = {
    bounce: { review: 5.0, pause: 10.0 },
    complaint: { review: 0.1, pause: 0.5 }
  }.freeze

  attr_reader :kind, :percent

  def initialize(kind, percent)
    @kind = kind
    @percent = percent
  end

  def review_at = THRESHOLDS.dig(kind, :review)
  def pause_at = THRESHOLDS.dig(kind, :pause)

  def status
    if percent >= pause_at
      :pause
    elsif percent >= review_at
      :review
    else
      :ok
    end
  end

  def ok? = status == :ok

  # How far the rate is toward the pause level, capped at 100.
  def percent_of_pause = [ percent / pause_at * 100, 100 ].min
  def review_percent_of_pause = review_at / pause_at * 100
end
