require File.dirname(__FILE__) + '/../test_helper'

class HolidayTest < ActiveSupport::TestCase
  fixtures :holidays
  
  def setup
    
  end
  
  def test_creation
    entry = Holiday.new
    assert(!entry.valid?)
    
    entry = Holiday.new(:day => "2009-01-01", :hours => 8)
    assert(entry.valid?)
  end
  
  def test_fixtures
    assert_equal 3, Holiday.find(:all).size
    
    holiday = Holiday.find(1)
    assert_not_nil holiday
  end
  
  def test_target_time
    minutes_a = Holiday.target_minutes(Time.local(2009, 1, 1).to_date, Time.local(2009, 1, 31).to_date)
    assert_equal 9840, minutes_a
    minutes_b = Holiday.target_minutes_month(1, 2009)
    assert_equal minutes_a, minutes_b
    
    minutes_a = Holiday.target_minutes_until_day(Date.today)
    minutes_b = Holiday.target_minutes_until_now()
    assert_equal minutes_a, minutes_b
  end
end
