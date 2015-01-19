class CreateWorkingHoursSnapshots < ActiveRecord::Migration
  def change
    create_table :working_hours_snapshots do |t|
      t.column "user_id", :integer, :null => false
      t.column "date", :date
      t.column "total", :integer
      t.column "target", :integer
      t.column "vacation_days", :float
    end
  end
end
