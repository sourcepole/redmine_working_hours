class WorkingHours < ActiveRecord::Base
  belongs_to :user
  belongs_to :project
  belongs_to :issue
  
  validates_presence_of :user, :project, :starting

  def self.find_current(user)
    find(:first, :conditions => ["ending IS NULL AND user_id=?", user.id], :order => "#{self.table_name}.starting DESC")
  end

  #Tasks to display
  def self.task_issues(project)
    admin = User.find_by_login('admin')
    project.issues.find(:all, :include => :status, 
      :conditions => ["((assigned_to_id=? OR assigned_to_id IS NULL) AND #{IssueStatus.table_name}.is_closed=?) OR assigned_to_id=?",
        User.current.id, false, admin.id],      
      :order => "#{Issue.table_name}.subject")
  end

  def self.recent_issues(user, days=90)
    maxissues = 10
    from = Time.now - days*24*3600
    admin = User.find_by_login('admin')
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
