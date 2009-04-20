class AddTimeEntryIdColumnToWorkingHours < ActiveRecord::Migration
  def self.up
    add_column :working_hours, :time_entry_id, :integer
  end

  def self.down
    remove_column :working_hours, :time_entry_id
  end
end
