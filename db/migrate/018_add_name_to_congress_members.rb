class AddNameToCongressMembers < ActiveRecord::Migration
  def self.up
    add_column :congress_members, :name, :string
  end

  def self.down
    remove_column :congress_members, :name
  end
end
