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
    Setting.plugin_redmine_working_hours[:workday_hours]
  end

  def self.find_current(user)
    where("ending IS NULL AND user_id=?", user.id).order("starting DESC").first
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

end
