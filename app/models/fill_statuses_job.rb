class FillStatusesJob < ActiveRecord::Base
  belongs_to :fill_status
  belongs_to :delayed_job, class_name: "::Delayed::Job"
end
