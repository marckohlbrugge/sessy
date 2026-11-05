require "test_helper"

class ReputationRateTest < ActiveSupport::TestCase
  test "bounce rate status follows the AWS review and pause levels" do
    assert_equal :ok, ReputationRate.new(:bounce, 4.99).status
    assert_equal :review, ReputationRate.new(:bounce, 5.0).status
    assert_equal :review, ReputationRate.new(:bounce, 9.99).status
    assert_equal :pause, ReputationRate.new(:bounce, 10.0).status
  end

  test "complaint rate status follows the AWS review and pause levels" do
    assert_equal :ok, ReputationRate.new(:complaint, 0.08).status
    assert_equal :review, ReputationRate.new(:complaint, 0.1).status
    assert_equal :pause, ReputationRate.new(:complaint, 0.5).status
  end

  test "meter positions are relative to the pause level and capped" do
    rate = ReputationRate.new(:complaint, 0.05)

    assert_in_delta 10.0, rate.percent_of_pause
    assert_in_delta 20.0, rate.review_percent_of_pause
    assert_equal 100, ReputationRate.new(:bounce, 40.0).percent_of_pause
  end
end
