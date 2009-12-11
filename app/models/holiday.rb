class Holiday < ActiveRecord::Base
  validates_presence_of :day, :hours

  WORKDAY_HOURS = 8

  def self.target_minutes(start_date, end_date)
    minutes = 0
    t = start_date
    num_days = (end_date - start_date + 1).to_int
    num_days.times do
      if t.wday != 0 and t.wday != 6
        # not a weekend
        holiday = find_by_day(t)
        if holiday.nil?
          # working day
          minutes += WORKDAY_HOURS * 60
        else
          # holiday on working day
          hours = WORKDAY_HOURS - holiday.hours
          if hours < 0
            hours = 0
          end
          minutes += hours * 60
        end
      end
      t += 1
    end

    minutes
  end

  def self.target_minutes_month(month, year = nil)
    start_date = Time.local(year || Time.now.year, month, 1).to_date
    # TODO: better end of month method?
    if month == 12
      end_date = Time.local(year || Time.now.year, 12, 31).to_date
    else
      end_date = Time.local(year || Time.now.year, (month+1), 1).to_date - 1
    end
    target_minutes(start_date, end_date)
  end

  def self.target_minutes_until_day(end_date)
    start_date = Time.local(Time.now.year, 1, 1).to_date
    target_minutes(start_date, end_date)    
  end

  def self.target_minutes_until_now()
    target_minutes_until_day(Date.today)
  end
end
