require File.dirname(__FILE__) + '/../test_helper'

class WorkingHoursTest < ActiveSupport::TestCase
  fixtures :working_hours, :users, :issues, :projects

  def setup
    @working_hours = WorkingHours.find(1)
    @user = users(:users_006)
    @issue = issues(:issues_001)
  end

  def test_creation
    entry = WorkingHours.new
    assert(!entry.valid?)
    
    entry = WorkingHours.new(:starting => Time.now, :user => @user, :project => @issue.project)
    assert(entry.valid?)

    entry = WorkingHours.new(:starting => Time.now, :user => @user, :project => @issue.project, :issue => @issue)
    assert(entry.valid?)
    
    entry = WorkingHours.new(:starting => Time.now, :user => @user, :project => @issue.project)
    assert(entry.valid?)
  end

  def test_list
    assert_equal 100, WorkingHours.list().size

    filter = { "begindate" => '2003-01-31' }
    assert_equal 85, WorkingHours.list(filter).size
    assert_equal 'redMine Admin', WorkingHours.list(filter)[3].user.name

    filter = { "begindate" => '2003-01-31', "userselect" => @user.id }
    assert_equal 24, WorkingHours.list(filter).size
    WorkingHours.list(filter).each { |entry| assert_equal @user, entry.user }
    assert_equal "Can't print recipes", WorkingHours.list(filter).first.issue.subject

    filter = { "begindate" => '2003-01-31', "userselect" => @user.id, "taskselect" => @issue.id.to_s }
    assert_equal 24, WorkingHours.list(filter).size
    WorkingHours.list(filter).each { |entry| assert_equal @issue, entry.issue }

    filter = { "begindate" => '2003-01-31', "enddate" => '2003-01-31', "userselect" => @user.id }
    assert_equal 5, WorkingHours.list(filter).size

    entry = WorkingHours.start(@user, '2003-01-31 23:00:00')
    entry.project = @issue.project
    entry.issue = @issue
    entry.save

    filter = { "begindate" => '2003-01-31', "enddate" => '2003-01-31', "userselect" => @user.id }
    assert_equal 6, WorkingHours.list(filter).size
  end

  def test_startstop
    current = WorkingHours.find_current(@user)
    assert_nil current

    entry = WorkingHours.start(@user, Time.now)
    assert_equal @user.id, entry.user_id
    #entry is not saved
    assert entry.running?
    entry.ending = Time.now
    assert !entry.running?

    # list
    filter = { "begindate" => Date.today, "userselect" => @user.id }
    assert_equal [], WorkingHours.list(filter)
    entry.project = @issue.project
    entry.issue = @issue
    entry.save
    assert_equal 1, WorkingHours.list(filter).size
  end

  def test_timecalc
    entry = WorkingHours.new( :starting => "2005-09-05 08:25:38", :ending => "2005-09-05 09:25:38" )
    assert_equal 60, entry.minutes
    entry.break = 10
    assert_equal 50, entry.minutes
    entry = WorkingHours.new( :starting => Time.now-70 )
    assert_equal 1, entry.minutes
  end

  def test_total_time
    minutes = WorkingHours.total_minutes(Time.local(2003, 1, 1).to_date, Time.local(2003, 12, 31).to_date)
    assert_equal 2162, minutes

    minutes_a = WorkingHours.total_minutes(Time.local(2004, 6, 1).to_date, Time.local(2004, 6, 30).to_date)
    assert_equal 717, minutes_a
    minutes_b = WorkingHours.total_minutes_month(6, 2004)
    assert_equal minutes_a, minutes_b

    minutes = WorkingHours.total_minutes_day(Time.local(2003, 1, 31).to_date)
    assert_equal 565, minutes

    minutes_a = WorkingHours.total_minutes_until_day(Date.today)
    assert_equal 0, minutes_a
    minutes_b = WorkingHours.total_minutes_until_now()
    assert_equal minutes_a, minutes_b
  end

  def test_diff_time
    diff = WorkingHours.diff_minutes(Time.local(2003, 1, 1).to_date, Time.local(2003, 10, 31).to_date)
    assert_equal(-102478, diff)

    diff_a = WorkingHours.diff_minutes_until_day(Date.today)
    diff_b = WorkingHours.diff_minutes_until_now()
    assert_equal diff_a, diff_b
  end
end
