class HolidayController < ApplicationController
  unloadable #Don't understand it, but prevents exception "A copy of ApplicationController has been removed from the module tree but is still active"
  layout 'base'
  before_filter :require_login
  accept_key_auth :index

  # TODO: permissions

  def index
    @holidays = Holiday.find(:all, :order => "#{Holiday.table_name}.day ASC")
    render :action => 'index'
  end

  def new
    @holiday = Holiday.new()
    @holiday.day = Date.today
    @holiday.hours = Holiday::WORKDAY_HOURS
  end

  def create
    @holiday = Holiday.new(params[:holiday])
    if @holiday.save
      flash[:notice] = 'Holiday was successfully created.'
      redirect_to :action => 'index'
    else
      render :action => 'new'
    end
  end

  def edit
    @holiday = Holiday.find(params[:id])
  end

  def update
    @holiday = Holiday.find(params[:id])
    @holiday.attributes = params[:holiday]
    if @holiday.save
      flash[:notice] = 'Holiday was successfully updated.'
      redirect_to :action => 'index'
    else
      render :action => 'edit'
    end
  end

  def destroy
    Holiday.find(params[:id]).destroy
    redirect_to :action => 'index'
  end
end
