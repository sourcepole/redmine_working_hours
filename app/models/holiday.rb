class Holiday < ActiveRecord::Base
  unloadable

  validates_presence_of :day, :hours
  validates :day, :date => true

end
