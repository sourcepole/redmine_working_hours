class WorkingHoursController < ApplicationController
  unloadable

  before_filter :require_login

  def index
    @working_hours = WorkingHours.where(:user_id => User.current.id).order("starting DESC")
    @minutes_total = @working_hours.inject(0) { |sum, w| sum + w.minutes }

    # pagination
    @working_hour_count = @working_hours.count
    @working_hour_pages = Paginator.new(@working_hour_count, per_page_option, params['page'])
    @working_hours = @working_hours.limit(@working_hour_pages.per_page).offset(@working_hour_pages.offset)
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
      redirect_to :action => 'index'
    else
      @issues = WorkingHours.task_issues(@working_hours.project)
      render :action => 'new'
    end
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
      redirect_to :action => 'index'
    else
      @issues = WorkingHours.task_issues(@working_hours.project)
      render :action => 'edit'
    end
  end

  def destroy
    WorkingHours.find(params[:id]).destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to :action => 'index'
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
    project = User.current.projects.find(params[:project_id])
    @issues = WorkingHours.task_issues(project)
  end

  private

  MINGAP = 60

  def working_hours_calculations
    case params['subform']
      when 'Timestamps'
        if params['running'] && params[:working_hours][:ending].empty?
          @working_hours.ending = nil
        end
        if @working_hours.starting.hour < WorkingHours::WORKDAY_CHANGE_HOUR
          @working_hours.workday = @working_hours.starting.to_date - 1
        else
          @working_hours.workday = @working_hours.starting.to_date
        end
      when 'Duration'
        @working_hours.starting = Time.local(@working_hours.workday.year, @working_hours.workday.month, @working_hours.workday.day)
        @working_hours.ending = @working_hours.starting + params['duration'].to_f * 3600
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

end
