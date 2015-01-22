class WorkingHoursController < ApplicationController
  unloadable

  before_filter :require_login
  accept_api_auth :index

  def index
    # filter
    filter_params = params[:filter] || {}

    if params[:format] == 'ics'
      params[:duration] ||= 365
      @begindate_filter = filter_params[:begindate] || Date.today - params[:duration].to_s.to_i
    else
      @begindate_filter = filter_params[:begindate] || Date.today
    end
    @enddate_filter = filter_params[:enddate] || Date.today

    # apply filter
    @working_hours = WorkingHours
    unless params[:users] == 'all' && User.current.admin?
      @working_hours = @working_hours.where(:user_id => User.current.id)
    end
    @working_hours = @working_hours.where("workday >= ? AND workday <= ?", @begindate_filter, @enddate_filter)
    @working_hours = @working_hours.where(:project_id => filter_params[:project_id]) unless filter_params[:project_id].blank?
    @working_hours = @working_hours.where(:issue_id => filter_params[:issue_id]) unless filter_params[:issue_id].blank?

    respond_to do |format|
      format.html {
        # filter form
        @project_filter_collection = User.current.projects.order(:name)
        @project_filter = filter_params[:project_id].to_s.to_i

        @issue_filter_collection = []
        unless filter_params[:project_id].blank?
          project = User.current.projects.find(filter_params[:project_id])
          @issue_filter_collection = WorkingHours.task_issues(project)
          @issue_filter = filter_params[:issue_id].to_s.to_i
        end

        @minutes_total = @working_hours.inject(0) { |sum, w| sum + w.minutes }

        # pagination
        @working_hour_count = @working_hours.count
        @working_hour_pages = Paginator.new(@working_hour_count, per_page_option, params['page'])
        @working_hours = @working_hours.order("starting DESC").limit(@working_hour_pages.per_page).offset(@working_hour_pages.offset)
      }
      format.csv {
        send_csv
      }
      format.ics {
        send_ics
      }
    end
  end

  def new
    @working_hours = WorkingHours.start(User.current, Time.now)
    project = User.current.projects.order(:name).first
    @issues = WorkingHours.task_issues(project)
  end

  def create
    @working_hours = WorkingHours.new(params[:working_hours])
    @working_hours.user = User.current
    working_hours_calculations
    if @working_hours.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :filter => params[:filter]
    else
      @issues = WorkingHours.task_issues(@working_hours.project)
      render :action => 'new'
    end
  end

  def new_vacation
    @working_hours = WorkingHours.new
    @vacation_start_date = Date.today
    @vacation_end_date = Date.today

    flash[:error] = l(:error_no_vacation_issue) if WorkingHours.vacation_issue.nil?
  end

  def create_vacation
    vacation_issue = WorkingHours.vacation_issue
    if vacation_issue.nil?
      flash[:error] = l(:error_no_vacation_issue)
      redirect_to :action => 'index', :filter => params[:filter]
      return
    end

    start_date = params[:vacation_start_date].to_date rescue nil
    end_date = params[:vacation_end_date].to_date rescue nil
    if start_date.nil? || end_date.nil? || end_date < start_date
      @working_hours = WorkingHours.new(params[:working_hours])
      @working_hours.errors.add(:starting, :invalid) if start_date.nil?
      @working_hours.errors.add(:ending, :invalid) if end_date.nil? || end_date < start_date
      @vacation_start_date = params[:vacation_start_date]
      @vacation_end_date = params[:vacation_end_date]
      render :action => 'new_vacation'
      return
    end

    vacation_project = vacation_issue.project
    holidays = Holiday.where("day >= ? AND day <= ?", start_date, end_date).pluck(:day)

    t = start_date
    num_days = (end_date - start_date + 1).to_int
    num_days.times do
      if t.wday != 0 and t.wday != 6
        # not a weekend
        working_hours = WorkingHours.new(params[:working_hours])
        working_hours.user = User.current
        working_hours.project = vacation_project
        working_hours.issue = vacation_issue
        working_hours.break = 0
        working_hours.workday = t
        working_hours.starting = t.to_time

        if holidays.include?(t)
          # holiday on working day
          holiday = Holiday.find_by_day(t)
          delta_hours = WorkingHours.workday_hours - holiday.hours
          if delta_hours > 0.0
            working_hours.ending = working_hours.starting + delta_hours.hours ## * 3600
            working_hours.save
          end
        else
          # working day
          working_hours.ending = working_hours.starting + WorkingHours.workday_hours.hours ### * 3600
          working_hours.save
        end
      end
      t += 1
    end

    flash[:notice] = l(:notice_successful_create)
    redirect_to :action => 'index', :filter => params[:filter]
  end

  def edit
    @working_hours = WorkingHours.find(params[:id])
    @issues = WorkingHours.task_issues(@working_hours.project)
  end

  def update
    @working_hours = WorkingHours.find(params[:id])
    @working_hours.attributes = params[:working_hours]
    working_hours_calculations
    if @working_hours.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index', :filter => params[:filter]
    else
      @issues = WorkingHours.task_issues(@working_hours.project)
      render :action => 'edit'
    end
  end

  def destroy
    WorkingHours.find(params[:id]).destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to :action => 'index', :filter => params[:filter]
  end

  def update_comments
    @working_hours = WorkingHours.find(params[:id])
    @working_hours.attributes = params[:working_hours]
    @working_hours.save
    render(:partial => 'my/blocks/working_hours')
  end

  def startstop
    project_id = params[:project_id].to_i
    issue_id = params[:issue_id].to_i
    @cur_entry = startstop_task(User.current, project_id, issue_id)
    render(:partial => 'my/blocks/working_hours')
  end

  def break
    @cur_entry = startstop_task(User.current, nil, nil, true)
    render(:partial => 'my/blocks/working_hours')
  end

  def project_issues
    if params[:project_id].blank?
      @issues = []
    else
      project = User.current.projects.find(params[:project_id])
      @issues = WorkingHours.task_issues(project)
    end
  end

  private

  MINGAP = 60

  def working_hours_calculations
    case params['subform']
      when 'Timestamps'
        if params['running'] && params[:working_hours][:ending].empty?
          @working_hours.ending = nil
        end
        unless @working_hours.starting.blank?
          if @working_hours.starting.hour < WorkingHours::WORKDAY_CHANGE_HOUR
            @working_hours.workday = @working_hours.starting.to_date - 1
          else
            @working_hours.workday = @working_hours.starting.to_date
          end
        end
      when 'Duration'
        unless @working_hours.workday.blank?
          @working_hours.starting = Time.local(@working_hours.workday.year, @working_hours.workday.month, @working_hours.workday.day)
          @working_hours.ending = @working_hours.starting + params['duration'].to_f * 3600
        end
    end
  end

  def startstop_task(user, new_project_id, new_issue_id, breakflag=false)
    logger.debug "startstop user #{user.name} task: #{new_project_id} break: #{breakflag}"
    starting = Time.now

    cur = WorkingHours.find_current(user)
    start_task = !(breakflag || new_project_id.nil? || new_project_id == 0)

    # stop current task
    if !cur.nil? && cur.running?
      logger.debug "stop entry #{cur.id} task: #{cur.project_id}"
      if new_project_id == cur.project_id && new_issue_id == cur.issue_id
        # Same task -> stop only
        start_task = false
      end
      cur.ending = starting
      if cur.ending - cur.starting < MINGAP && start_task
        # replace short entry by new one
        starting = cur.starting
        cur.destroy
      else
        cur.save
      end
    elsif start_task
      # check short entries or short gaps
      cur = WorkingHours.where(:user_id => user.id).order("starting DESC").first
      unless cur.nil?
        if cur.ending - cur.starting < MINGAP
          # replace short entry by new one
          starting = cur.starting
          cur.destroy
        elsif starting - cur.ending < MINGAP
          # no gap
          starting = cur.ending
        end
        cur = nil
      end
    end

    # start new task
    if start_task
      prev = WorkingHours.where({:user_id => user.id, :project_id => new_project_id}).order("starting DESC").first
      cur = WorkingHours.start(user, starting)
      logger.debug "start entry #{cur.id} task: #{cur.project_id}"
      cur.project_id = new_project_id
      cur.issue_id = new_issue_id
      cur.comments = prev.comments if !prev.nil? && starting - prev.ending < 10*3600
      cur.save!
    end

    cur
  rescue Exception => e
    logger.error "Error in startstop user #{user.name} task: #{new_project_id} break: #{breakflag} : #{e.message}"
    nil
  end

  def send_csv
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = ['User', 'Project', 'Ticket', 'Title', 'Date', 'Begin', 'Break', 'End', 'Comment', 'Duration']
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding) ) }

      # csv lines
      @working_hours.order("starting").each do |entry|
        fields = [
          (entry.user ? entry.user.name : nil),
          entry.project.name,
          (entry.issue ? entry.issue_id : nil),
          (entry.issue ? entry.issue.subject : nil),
          entry.workday.to_formatted_s(:european),
          (entry.starting ? entry.starting.to_formatted_s(:time) : nil),
          entry.break,
          (entry.ending ? entry.ending.to_formatted_s(:time) : nil),
          entry.comments,
          entry.minutes
        ]
        csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding) ) }
      end
    end

    send_data(export, :type => 'text/csv; header=present', :filename => 'export.csv')
  end

  def send_ics
    export = "BEGIN:VCALENDAR\n"
    export << "VERSION:2.0\n"
    export << "PRODID:-//Sourcepole//NONSGML Redmine Working Hours//EN\n"
    @working_hours.order("starting").each do |entry|
      next if entry.ending.nil?

      export << "BEGIN:VEVENT\n"
      export << "DTSTART:#{entry.starting.utc.strftime("%Y%m%dT%H%M%SZ")}\n"
      export << "DTEND:#{entry.ending.utc.strftime("%Y%m%dT%H%M%SZ")}\n"
      task = entry.issue ? "\\n##{entry.issue_id} #{entry.issue.subject}": ""
      export << "SUMMARY:#{entry.project.name}#{task}\n"
      comments = entry.comments.to_s.gsub(/\r\n|\n/, "\\n")
      export << "DESCRIPTION:#{comments}\n"
      export << "ATTENDEE:#{entry.user ? "#{entry.user.firstname} #{entry.user.lastname}" : ""}\n"
      export << "END:VEVENT\n"
    end

    export << "END:VCALENDAR\n"

    send_data(export, :type => 'text/calendar', :filename => 'export.ics')
  end

end
