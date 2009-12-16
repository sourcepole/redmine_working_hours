class WorkingHoursSnapshot < ActiveRecord::Base
  belongs_to :user
  
  validates_presence_of :user, :date

  def self.find_current(user, start_date, end_date)
    find :first, :conditions => ["user_id=? AND date>=? AND date<=?", user.id, start_date, end_date], :order => "#{WorkingHoursSnapshot.table_name}.date DESC"
  end
end