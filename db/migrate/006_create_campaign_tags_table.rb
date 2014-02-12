class CreateCampaignTagsTable < ActiveRecord::Migration
  def self.up
    create_table :campaign_tags do |t|
      t.string  :name
    end
  end

  def self.down
    drop_table :campaign_tags
  end
end
