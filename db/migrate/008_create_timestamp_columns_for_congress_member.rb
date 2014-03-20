class CreateTimestampColumnsForCongressMember < ActiveRecord::Migration
  def self.up
    add_column :congress_members, :created_at, :datetime
    add_column :congress_members, :updated_at, :datetime
  end

  def self.down
    remove_column :congress_members, :created_at
    remove_column :congress_members, :updated_at
  end
end
