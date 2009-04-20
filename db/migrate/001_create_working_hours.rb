class CreateWorkingHours < ActiveRecord::Migration
  def self.up
    create_table :working_hours do |t|
      t.column "project_id",  :integer
      t.column "user_id",     :integer,  :null => false
      t.column "issue_id",    :integer
      t.column "comments",    :string
      #t.column "activity_id", :integer
      t.column "workday",     :date
      t.column "starting",    :datetime
      t.column "ending",      :datetime
      t.column "break",       :integer
    end rescue nil
  end

  def self.down
    drop_table :working_hours
  end
end
