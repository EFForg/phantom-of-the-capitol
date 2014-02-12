class CreateFillSuccessesTable < ActiveRecord::Migration
  def self.up
    create_table :fill_successes do |t|
      t.integer  :congress_member_id
      t.integer :campaign_tag_id
      t.timestamps
    end
  end

  def self.down
    drop_table :fill_successes
  end
end
