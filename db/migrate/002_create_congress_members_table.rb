class CreateCongressMembersTable < ActiveRecord::Migration
  def self.up
    create_table :congress_members do |t|
      t.string  :bioguide_id
    end
    add_index :congress_members, :bioguide_id, :unique => true
  end

  def self.down
    drop_table :congress_members
  end
end
