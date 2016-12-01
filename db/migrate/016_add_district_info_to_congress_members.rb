class AddDistrictInfoToCongressMembers < ActiveRecord::Migration
  def self.up
    add_column :congress_members, :state, :string
    add_column :congress_members, :chamber, :string
    add_column :congress_members, :house_district, :integer
    add_column :congress_members, :senate_class, :integer
  end

  def self.down
    remove_column :congress_members, :state
    remove_column :congress_members, :chamber
    remove_column :congress_members, :house_district
    remove_column :congress_members, :senate_class
  end
end
