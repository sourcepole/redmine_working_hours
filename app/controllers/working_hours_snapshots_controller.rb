class WorkingHoursSnapshotsController < ApplicationController
  unloadable

  before_filter :require_admin

  def index
    @snapshots = WorkingHoursSnapshot.order("date DESC")

    # pagination
    @snapshot_count = @snapshots.count
    @snapshot_pages = Paginator.new(@snapshot_count, per_page_option, params['page'])
    @snapshots = @snapshots.limit(@snapshot_pages.per_page).offset(@snapshot_pages.offset)
  end

  def new
    @snapshot = WorkingHoursSnapshot.new(:user_id => User.current.id, :date => Date.today, :total => 0, :target => 0, :vacation_days => 0)
    @users = User.sorted
  end

  def create
    @snapshot = WorkingHoursSnapshot.new(params[:working_hours_snapshot])
    if @snapshot.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index'
    else
      @users = User.sorted
      render :action => 'new'
    end
  end

  def edit
    @snapshot = WorkingHoursSnapshot.find(params[:id])
    @users = User.sorted
  end

  def update
    @snapshot = WorkingHoursSnapshot.find(params[:id])
    @snapshot.attributes = params[:working_hours_snapshot]
    if @snapshot.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index'
    else
      @users = User.sorted
      render :action => 'edit'
    end
  end

  def destroy
    WorkingHoursSnapshot.find(params[:id]).destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to :action => 'index'
  end

end
