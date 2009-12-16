class WorkingHoursSnapshotController < ApplicationController
  unloadable #Don't understand it, but prevents exception "A copy of ApplicationController has been removed from the module tree but is still active"
  layout 'base'
  before_filter :require_login
  accept_key_auth :index

  # TODO: permissions
  
  def index
    @snapshots = WorkingHoursSnapshot.find :all, :order => "#{WorkingHoursSnapshot.table_name}.date DESC"
    @users = User.find(:all)
    render :action => 'index'
  end

  def new
    @snapshot = WorkingHoursSnapshot.new(:user_id => User.current.id, :date => Date.today)
    # TODO: update values when selecting user from list
    @snapshot.total = WorkingHours.total_minutes_until_day(Date.today - 1)
    @snapshot.target = Holiday.target_minutes_until_day(Date.today - 1)
    @snapshot.vacation_days = WorkingHours.vacation_days_used()
    @users = User.find(:all)
  end

  def create
    @snapshot = WorkingHoursSnapshot.new(params[:snapshot])
    if @snapshot.save
      flash[:notice] = 'WorkingHoursSnapshot was successfully created.'
      redirect_to :action => 'index'
    else
      render :action => 'new'
    end
  end

  def edit
    @snapshot = WorkingHoursSnapshot.find(params[:id])
  end

  def update
    @snapshot = WorkingHoursSnapshot.find(params[:id])
    @snapshot.attributes = params[:snapshot]
    if @snapshot.save
      flash[:notice] = 'WorkingHoursSnapshot was successfully updated.'
      redirect_to :action => 'index'
    else
      render :action => 'edit'
    end
  end

  def destroy
    WorkingHoursSnapshot.find(params[:id]).destroy
    redirect_to :action => 'index'
  end
end
