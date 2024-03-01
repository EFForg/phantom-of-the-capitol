class ChangeCongressMemberActionsValueType < ActiveRecord::Migration
  def self.up
    change_column :congress_member_actions, :value, :text, limit: 65535
  end

  def self.down
    change_column :congress_member_actions, :value, :string, limit: 511
  end
end

