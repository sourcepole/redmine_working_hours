class CreateWorkingHours < ActiveRecord::Migration
  def change
    create_table :working_hours do |t|
      t.column "project_id", :integer
      t.column "user_id", :integer, :null => false
      t.column "issue_id", :integer
      t.column "time_entry_id", :integer
      t.column "comments", :string
      t.column "workday", :date
      t.column "starting", :datetime
      t.column "ending", :datetime
      t.column "break", :integer
    end
  end
end
