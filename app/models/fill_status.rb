class FillStatus < ActiveRecord::Base
  scope :success, conditions: "status = 'success'"
  scope :error, conditions: "status = 'error'"
  scope :failure, conditions: "status = 'failure'"

  belongs_to :congress_member
  belongs_to :campaign_tag

  def initialize attrs = {}
    ct = CampaignTag.find_or_create_by_name attrs.delete(:campaign_tag) if attrs.include? :campaign_tag
    super attrs
    self.campaign_tag = ct
  end
end
