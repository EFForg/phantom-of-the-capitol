class ExtendCongressMemberActionsValue < ActiveRecord::Migration
  def self.up
    change_column :congress_member_actions, :value, :string, limit: 511
  end

  def self.down
    change_column :congress_member_actions, :value, :string, limit: 255
  end
end
