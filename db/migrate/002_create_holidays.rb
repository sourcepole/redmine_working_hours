class CreateHolidays < ActiveRecord::Migration
  def change
    create_table :holidays do |t|
      t.column "day",  :date
      t.column "hours", :float
    end
  end
end
