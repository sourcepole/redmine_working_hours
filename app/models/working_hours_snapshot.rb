class WorkingHoursSnapshot < ActiveRecord::Base
  unloadable

  belongs_to :user

  validates_presence_of :user, :date
  validates :date, :date => true

end
