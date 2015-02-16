class WorkingHours < ActiveRecord::Base
  unloadable

  belongs_to :user
  belongs_to :project
  belongs_to :issue
  belongs_to :time_entry, :dependent => :destroy

  validates_presence_of :user, :project, :workday, :starting
  validate :validate_ending_after_starting

  before_save :update_time_entry

  COMMON_TASKS_USER = 'admin'
  WORKDAY_CHANGE_HOUR = 5

  def validate_ending_after_starting
    errors.add(:ending, :invalid) if !starting.nil? && !ending.nil? && ending < starting
  end

  def self.workday_hours
    Setting.plugin_redmine_working_hours[:workday_hours].to_f
  end

  def self.find_current(user)
    where("ending IS NULL AND user_id=?", user.id).order("#{self.table_name}.starting DESC").first
  end

  # Tasks to display
  def self.task_issues(project)
    admin = User.find_by_login(COMMON_TASKS_USER)
    project.issues.includes(:status).where("((assigned_to_id = ? OR assigned_to_id IS NULL) AND #{IssueStatus.table_name}.is_closed = ?) OR assigned_to_id=?", User.current.id, false, admin.id).order("#{Issue.table_name}.subject")
  end

  def self.recent_issues(user, days_before_now=90)
    max_issues = 10
    from = Time.now - days_before_now.days
    admin = User.find_by_login(COMMON_TASKS_USER)
    issues = where("issue_id IS NOT NULL AND issue_id > 0 AND user_id = ? AND workday >= '#{Date.new(from.year, from.month, from.day)}'", user.id).order("#{self.table_name}.starting DESC").includes(:issue).collect { |w| w.issue }
    issues.uniq.select {|issue| !issue.status.is_closed || issue.assigned_to == admin }[0, max_issues]
  end

  def self.start(user, starting)
    rec = self.new
    rec.user_id = user.id
    rec.starting = starting
    rec.break = 0
    rec.workday = starting
    rec
  end

  def minutes
    return 0 if starting.nil?
    endtime = ending || Time.now
    seconds = endtime - starting
    breakminutes = self.break || 0
    (seconds/60).round - breakminutes
  end

  def running?
    !starting.nil? && ending.nil?
  end

  def update_time_entry
    if self.time_entry.nil?
      unless ending.nil?
        activity = Enumeration.where({:type => 'TimeEntryActivity', :is_default => true}).order(:position).first || Enumeration.find_by_type('TimeEntryActivity')

        new_time_entry = project.time_entries.build(:issue => issue, :user => user, :spent_on => workday)
        new_time_entry.hours = minutes/60.0
        new_time_entry.activity_id = activity.id
        new_time_entry.comments = comments
        if new_time_entry.save!
          self.time_entry_id = new_time_entry.id
        end
      end
    else
      time_entry.update_attributes(:project => project, :issue => issue, :hours => minutes/60.0, :comments => comments)
    end
  rescue Exception => e
    logger.error "Error in update_time_entry(), working_hour '#{id}', time_entry '#{time_entry_id}' : #{e.message}"
    nil
  end

  # total time

  def self.total_minutes(start_date, end_date, user)
    minutes = 0

    snapshot = WorkingHoursSnapshot.find_current(user, start_date, end_date)
    unless snapshot.nil?
      start_date = snapshot.date
      minutes = snapshot.total
    end

    working_hours = WorkingHours.where(:user_id => user.id).where("workday >= ? AND workday <= ?", start_date, end_date)
    working_hours.inject(minutes) { |sum, j| sum + j.minutes }
  end

  def self.total_minutes_day(date, user=User.current)
    total_minutes(date, date, user)
  end

  def self.total_minutes_month(month, year=Time.now.year, user=User.current)
    start_date = Date.new(year, month, 1)
    end_date = last_day_of_month(month, year)
    total_minutes(start_date, end_date, user)
  end

  # target time

  def self.target_minutes(start_date, end_date, user)
    minutes = 0

    snapshot = WorkingHoursSnapshot.find_current(user, start_date, end_date)
    unless snapshot.nil?
      start_date = snapshot.date
      minutes = snapshot.target
    end

    holidays = Holiday.where("day >= ? AND day <= ?", start_date, end_date).pluck(:day)
    t = start_date
    num_days = (end_date - start_date + 1).to_int
    num_days.times do
      if t.wday != 0 and t.wday != 6
        # not a weekend
        if holidays.include?(t)
          # holiday on working day
          holiday = Holiday.find_by_day(t)
          hours = workday_hours - holiday.hours
          if hours < 0
            hours = 0
          end
          minutes += hours * 60
        else
          # working day
          minutes += workday_hours * 60
        end
      end
      t += 1
    end

    minutes *= user_pensum(user)
    minutes
  end

  def self.target_minutes_month(month, year=Time.now.year, user=User.current)
    start_date = Date.new(year, month, 1)
    end_date = last_day_of_month(month, year)
    target_minutes(start_date, end_date, user)
  end

  # difference to target time

  def self.diff_minutes(start_date, end_date, user=User.current)
    total_minutes(start_date, end_date, user) - target_minutes(start_date, end_date, user)
  end

  # difference to target time since beginning of year
  def self.diff_minutes_until_day(end_date, user=User.current)
    start_date = Date.new(end_date.year, 1, 1)
    diff_minutes(start_date, end_date, user)
  end

  # vacation days

  def self.vacation_issue
    Issue.find_by_id(Setting.plugin_redmine_working_hours[:vacation_issue_id])
  end

  def self.vacation_days_available(user=User.current)
    user_vacation_days = 0
    custom_field = CustomField.find_by_name('working_hours_vacation_days')
    unless custom_field.nil?
      cv = CustomValue.where(:custom_field_id => custom_field.id).where(:customized_id => user.id).first
      unless cv.nil?
        user_vacation_days = cv.value.to_i
      end
    end

    start_date = Date.new(Time.now.year, 1, 1)
    end_date = Date.today
    days_used = 0.0

    snapshot = WorkingHoursSnapshot.find_current(user, start_date, end_date)
    unless snapshot.nil?
      start_date = snapshot.date
      days_used = snapshot.vacation_days
    end

    unless vacation_issue.nil?
      holidays = Holiday.where("day >= ? AND day <= ?", start_date, end_date).pluck(:day)
      working_hours = WorkingHours.where(:user_id => user.id).where(:issue_id => vacation_issue.id).where("workday >= ? AND workday <= ?", start_date, end_date)
      working_hours.each do |wh|
        if wh.workday.wday != 0 and wh.workday.wday != 6
          unless holidays.include?(wh.workday)
            # not a weekend and not a holiday
            if wh.minutes/60.0 > workday_hours/2.0
              days_used += 1.0
            else
              days_used += 0.5
            end
          end
        end
      end
    end

    user_vacation_days - days_used
  end

  # helpers

  def self.last_day_of_month(month, year=Time.now.year)
    if month == 12
      Date.new(year, 12, 31)
    else
      Date.new(year, (month + 1), 1) - 1.day
    end
  end

  def self.user_pensum(user)
    pensum = 1.0
    custom_field = CustomField.find_by_name('working_hours_pensum')
    unless custom_field.nil?
      cv = CustomValue.where(:custom_field_id => custom_field.id).where(:customized_id => user.id).first
      unless cv.nil?
        pensum = cv.value.to_f
      end
    end
    pensum
  end

end
