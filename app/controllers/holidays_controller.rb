class HolidaysController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :require_admin, :except => :index

  def index
    @holidays = Holiday.order("day DESC")

    # pagination
    @holiday_count = @holidays.count
    @holiday_pages = Paginator.new(@holiday_count, per_page_option, params['page'])
    @holidays = @holidays.limit(@holiday_pages.per_page).offset(@holiday_pages.offset)
  end

  def new
    @holiday = Holiday.new(:day => Date.today, :hours => WorkingHours.workday_hours)
  end

  def create
    @holiday = Holiday.new(params[:holiday])
    if @holiday.save
      flash[:notice] = l(:notice_successful_create)
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
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index'
    else
      render :action => 'edit'
    end
  end

  def destroy
    Holiday.find(params[:id]).destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to :action => 'index'
  end

end
