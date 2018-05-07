class CongressMember < ActiveRecord::Base
  require_dependency "app/helpers/message_fields_helper"
  include MessageFieldsHelper
  include FormFilling
  include CwcMessaging

  validates_presence_of :bioguide_id

  has_many :actions, class_name: 'CongressMemberAction', dependent: :destroy
  has_many :required_actions, -> (object) { where "required = true AND SUBSTRING(value, 1, 1) = '$'" },
    class_name: 'CongressMemberAction'
  has_many :fill_statuses, class_name: 'FillStatus', dependent: :destroy
  has_many :recent_fill_statuses, -> (object) { where("created_at > ?", object.updated_at) },
    class_name: 'FillStatus'

  serialize :success_criteria, LegacySerializer

  RECENT_FILL_IMAGE_BASE = 'https://img.shields.io/badge/'
  RECENT_FILL_IMAGE_EXT = '.svg'

  def has_captcha?
    actions.solved_captcha.exists?
  end

  def recent_fill_status
    statuses = recent_fill_statuses
    {
      successes: statuses.success.count,
      errors: statuses.error.count,
      failures: statuses.failure.count
    }
  end

  def as_required_json o={}
    as_json({
      only: [],
      include: {
        required_actions: {
          only: [ :value, :maxlength ], methods: [:options_hash]
        }
      }
    }.merge o)
  end

  class << self
    def to_hash cm_array
      cm_hash = {}
      cm_array.each do |cm|
        cm_hash[cm.id.to_s] = cm
      end
      cm_hash
    end

    def retrieve_cached cm_hash, cm_id
      return cm_hash[cm_id] if cm_hash.include? cm_id
      cm_hash[cm_id] = self.find(cm_id)
    end
  end
end
