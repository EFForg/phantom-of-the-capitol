class AddDefunctAndContactUrlToCongressMembers < ActiveRecord::Migration
  def self.up
    add_column :congress_members, :defunct, :boolean, default: false
    add_column :congress_members, :contact_url, :string
  end

  def self.down
    remove_column :congress_members, :defunct
    remove_column :congress_members, :contact_url
  end
end
