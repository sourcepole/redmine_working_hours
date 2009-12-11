class CreateHolidays < ActiveRecord::Migration
  def self.up
    create_table :holidays do |t|
      t.column "day",  :date
      t.column "hours", :float
    end rescue nil
  end

  def self.down
    drop_table :holidays
  end
end
