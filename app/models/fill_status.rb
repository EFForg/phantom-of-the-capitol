class FillStatus < ActiveRecord::Base
  scope :success, -> { where "status = 'success'" }
  scope :error, -> { where "status = 'error'" }
  scope :failure, -> { where "status = 'failure'" }
  scope :error_or_failure, -> { where "status = 'error' or status = 'failure'" }

  belongs_to :congress_member
  belongs_to :campaign_tag

  def initialize attrs = {}
    ct = CampaignTag.find_or_create_by(name: attrs.delete(:campaign_tag)) if attrs.include? :campaign_tag
    super attrs
    self.campaign_tag = ct
  end
end
