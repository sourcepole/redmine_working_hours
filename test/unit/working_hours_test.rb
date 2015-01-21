require File.expand_path('../../test_helper', __FILE__)

class WorkingHoursTest < ActiveSupport::TestCase
  self.fixture_path = File.expand_path("../../fixtures/", __FILE__)
  fixtures :working_hours, :holidays, :users, :projects, :issues

  def setup
    @user = users(:users_002)
  end

  def test_helpers
    date = WorkingHours.last_day_of_month(1, 2015)
    assert_equal Date.new(2015, 1, 31), date

    date = WorkingHours.last_day_of_month(2, 2015)
    assert_equal Date.new(2015, 2, 28), date

    date = WorkingHours.last_day_of_month(4, 2015)
    assert_equal Date.new(2015, 4, 30), date

    date = WorkingHours.last_day_of_month(12, 2015)
    assert_equal Date.new(2015, 12, 31), date

    date = WorkingHours.last_day_of_month(2, 2016)
    assert_equal Date.new(2016, 2, 29), date
  end

  def test_total_minutes
    minutes = WorkingHours.total_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 1), @user)
    assert_equal 0, minutes

    minutes = WorkingHours.total_minutes(Date.new(2015, 1, 5), Date.new(2015, 1, 5), @user)
    assert_equal 480, minutes

    minutes = WorkingHours.total_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 6), @user)
    assert_equal 960, minutes

    minutes = WorkingHours.total_minutes(Date.new(2015, 2, 1), Date.new(2015, 2, 1), @user)
    assert_equal 480, minutes

    minutes = WorkingHours.total_minutes_month(1, 2015, @user)
    assert_equal 1440, minutes

    minutes = WorkingHours.total_minutes_month(2, 2015, @user)
    assert_equal 960, minutes

    # without snapshot
    minutes = WorkingHours.total_minutes(Date.new(2015, 1, 1), Date.new(2015, 2, 28), @user)
    assert_equal 2400, minutes

    # with snapshot
    snapshot = WorkingHoursSnapshot.create(:user_id => @user.id, :date => Date.new(2015, 2, 1), :total => 40, :target => 0, :vacation_days => 0)
    minutes = WorkingHours.total_minutes(Date.new(2015, 1, 1), Date.new(2015, 2, 28), @user)
    assert_equal 1000, minutes
  end

  def test_target_minutes
    minutes = WorkingHours.target_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 5), @user)
    assert_equal 480, minutes

    minutes = WorkingHours.target_minutes_month(1, 2015, @user)
    assert_equal 9360, minutes

    minutes = WorkingHours.target_minutes_month(2, 2015, @user)
    assert_equal 9600, minutes

    # without snapshot
    minutes = WorkingHours.target_minutes(Date.new(2015, 1, 1), Date.new(2015, 2, 28), @user)
    assert_equal 18960, minutes

    # with snapshot
    snapshot = WorkingHoursSnapshot.create(:user_id => @user.id, :date => Date.new(2015, 2, 1), :total => 0, :target => 400, :vacation_days => 0)
    minutes = WorkingHours.target_minutes(Date.new(2015, 1, 1), Date.new(2015, 2, 28), @user)
    assert_equal 10000, minutes
  end

  def test_diff_minutes
    minutes = WorkingHours.diff_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 5), @user)
    assert_equal 0, minutes

    minutes = WorkingHours.diff_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 7), @user)
    assert_equal 0, minutes

    minutes = WorkingHours.diff_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 8), @user)
    assert_equal -480, minutes

    minutes = WorkingHours.diff_minutes(Date.new(2015, 1, 1), Date.new(2015, 1, 31), @user)
    assert_equal -7920, minutes

    minutes = WorkingHours.diff_minutes_until_day(Date.new(2015, 1, 31), @user)
    assert_equal -7920, minutes

    # without snapshot
    minutes = WorkingHours.diff_minutes_until_day(Date.new(2015, 2, 28), @user)
    assert_equal -16560, minutes

    # with snapshot
    snapshot = WorkingHoursSnapshot.create(:user_id => @user.id, :date => Date.new(2015, 2, 1), :total => 40, :target => 200, :vacation_days => 0)
    minutes = WorkingHours.diff_minutes_until_day(Date.new(2015, 2, 28), @user)
    assert_equal -8800, minutes
  end

end
