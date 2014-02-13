class FillSuccess < ActiveRecord::Base
  belongs_to :congress_member
  belongs_to :campaign_tag

  def initialize attrs = {}
    ct = CampaignTag.find_or_create_by_name attrs.delete(:name) if attrs.include? :name
    super attrs
    self.campaign_tag = ct
  end
end
