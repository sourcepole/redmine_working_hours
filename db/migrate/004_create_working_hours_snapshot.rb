class CreateWorkingHoursSnapshot < ActiveRecord::Migration
  def self.up
    create_table :working_hours_snapshots do |t|
      t.column "user_id",       :integer,  :null => false
      t.column "date",          :date
      t.column "total",         :integer
      t.column "target",        :integer
      t.column "vacation_days", :float
    end rescue nil
  end

  def self.down
    drop_table :working_hours_snapshots
  end
end
