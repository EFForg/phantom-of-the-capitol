# Indicates whether a form fill was successful.
# status:
#   failure - indicates that all the actions were performed successfully, but
#             the success criteria listed in the congress member's .yaml file
#             was not met.
#   error   - indicates that there was an error while performing the actions of
#             filling the form.
#   success - All of the actions were performed successfully and the
#             "success criteria" was met
#
class FillStatus < ActiveRecord::Base
  scope :success, -> { where "status = 'success'" }
  scope :error, -> { where "status = 'error'" }
  scope :failure, -> { where "status = 'failure'" }
  scope :error_or_failure, -> { where "status = 'error' or status = 'failure'" }

  belongs_to :congress_member
  belongs_to :campaign_tag

  has_one :fill_statuses_job, class_name: "::FillStatusesJob", dependent: :destroy
  has_one :delayed_job, through: :fill_statuses_job

  serialize :extra, LegacySerializer

  def initialize attrs = {}
    ct = CampaignTag.find_or_create_by(name: attrs.delete(:campaign_tag)) if attrs.include? :campaign_tag
    super attrs
    self.campaign_tag = ct
  end

  def success?
    status == "success"
  end
end
