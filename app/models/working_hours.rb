class WorkingHours < ActiveRecord::Base
  belongs_to :user
  belongs_to :project
  belongs_to :issue
  belongs_to :time_entry #, :dependent => :destroy
  
  validates_presence_of :user, :project, :starting

  before_save :update_time_entry
  before_destroy :destroy_time_entry
  
  COMMON_TASKS_USER = 'admin'

  def self.find_current(user)
    find(:first, :conditions => ["ending IS NULL AND user_id=?", user.id], :order => "#{self.table_name}.starting DESC")
  end

  #Tasks to display
  def self.task_issues(project)
    admin = User.find_by_login(COMMON_TASKS_USER)
    project.issues.find(:all, :include => :status, 
      :conditions => ["((assigned_to_id=? OR assigned_to_id IS NULL) AND #{IssueStatus.table_name}.is_closed=?) OR assigned_to_id=?",
        User.current.id, false, admin.id],      
      :order => "#{Issue.table_name}.subject")
  end

  def self.recent_issues(user, days=90)
    maxissues = 10
    from = Time.now - days*24*3600
    admin = User.find_by_login(COMMON_TASKS_USER)
    issues = find(:all, :include => :issue,
      :conditions => ["issue_id IS NOT NULL AND issue_id > 0 AND user_id=? AND workday>='#{Date.new(from.year, from.month, from.day)}'", user.id],
      :order => "#{self.table_name}.starting DESC").collect { |r| r.issue }
    issues.uniq.select {|issue| !issue.status.is_closed || issue.assigned_to == admin }[0,maxissues]
  end

  def self.list(filter = nil)
    filtersql, args = filter_sql(filter)
    find(:all, :conditions => [filtersql].concat(args), :order => "#{self.table_name}.starting DESC")
  end

  def self.start(user, starting)
    rec = self.new
    rec.user_id = user.id
    rec.starting = starting
    rec.break = 0
    rec.workday = starting #? date only
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
        activity = Enumeration.default('ACTI') || Enumeration.find_by_opt('ACTI')

        # TODO: does not work in this version
#        new_time_entry = project.time_entries.build(:issue => issue, :user => user, :spent_on => workday)

        # TODO: remove if above code works
        cur_project = Project.find(project_id)
        cur_issue = Issue.find(issue_id)
        cur_user = User.find(user_id)
        new_time_entry = TimeEntry.new(:project => cur_project, :issue => cur_issue, :user => cur_user, :spent_on => workday)
        
        new_time_entry.hours = minutes/60.0
        new_time_entry.activity_id = activity.id
        new_time_entry.comments = comments
        
        if new_time_entry.save!
          self.time_entry_id = new_time_entry.id
        end
      end
    else
      # TODO: only works the first time?
#      res = time_entry(true).update_attributes(:project => project, :issue => issue, :hours => minutes/60.0, :comments => comments)

      # TODO: remove if above code works
      cur_time_entry = TimeEntry.find(self.time_entry_id)
      unless cur_time_entry.nil?
        cur_time_entry.project_id = project_id
        cur_time_entry.issue_id = issue_id
        cur_time_entry.hours = minutes/60.0
        cur_time_entry.comments = comments
        cur_time_entry.save!
      end
    end
  rescue Exception => e
    logger.error "Error in update_time_entry(), working_hour '#{id}', time_entry '#{time_entry_id}' :" + e
    nil
  end
  
  # TODO: use 'belongs_to ... ,:dependent => :destroy' as soon as it works
  def destroy_time_entry
    unless self.time_entry_id.nil?
      cur_time_entry = TimeEntry.find(self.time_entry_id)
      unless cur_time_entry.nil?
        cur_time_entry.destroy
      end
    end
  end
  
  private

  def self.filter_sql(filter)
    filter ||= {}
    sql = ''
    args = []
    if filter["begindate"] then
      sql << "workday >= ?"
      args << filter["begindate"]
    end
    if filter["enddate"] then
      sql << " AND " if sql.length > 0
      sql << "workday <= ?"
      args << filter["enddate"]
    end
    if filter["mode"] then
      case filter["mode"].downcase
      when "today"
        sql = "(#{sql} OR ending IS NULL)"
      end
    end
    task_id = filter["taskselect"].to_i rescue nil
    if task_id && task_id != -1 && !filter["taskselect"].nil? then
      sql << " AND " if sql.length > 0
      sql << "issue_id = ?"
      args << task_id
    end
    user_id = filter["userselect"].to_i
    if user_id != 0 && user_id != -1 then
      sql << " AND " if sql.length > 0
      sql << "user_id = ?"
      args << user_id
    end
    sql = '1=1' if sql == '' #avoid empty where clause
    [sql, args]
  end
end
