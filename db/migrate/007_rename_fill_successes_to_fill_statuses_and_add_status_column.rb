class RenameFillSuccessesToFillStatusesAndAddStatusColumn < ActiveRecord::Migration
  def self.up
    rename_table :fill_successes, :fill_statuses
    add_column :fill_statuses, :status, :string
    FillStatus.update_all(status: "success")
  end

  def self.down
    remove_column :fill_statuses, :status
    rename_table :fill_statuses, :fill_successes
  end
end
