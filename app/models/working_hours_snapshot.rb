class WorkingHoursSnapshot < ActiveRecord::Base
  unloadable

  belongs_to :user

  validates_presence_of :user, :date
  validates :date, :date => true

  def self.find_current(user, start_date, end_date)
    where(:user_id => user.id).where("date >= ? AND date <= ?", start_date, end_date).order("date DESC").first
  end

end
