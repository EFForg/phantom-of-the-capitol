class AddExtraToFillStatuses < ActiveRecord::Migration
  def self.up
    add_column :fill_statuses, :extra, :string
  end

  def self.down
    remove_column :fill_statuses, :extra
  end
end
