class FillSuccess < ActiveRecord::Base
  belongs_to :congress_member
  belongs_to :campaign_tag
end
