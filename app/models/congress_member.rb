class CongressMember < ActiveRecord::Base
  require_dependency "app/helpers/message_fields_helper"
  include MessageFieldsHelper
  include FormFilling
  include CwcMessaging

  validates_presence_of :bioguide_id

  has_many :actions, :class_name => 'CongressMemberAction', :dependent => :destroy
  has_many :required_actions, -> (object) { where "required = true AND SUBSTRING(value, 1, 1) = '$'" }, :class_name => 'CongressMemberAction'
  has_many :fill_statuses, :class_name => 'FillStatus', :dependent => :destroy
  has_many :recent_fill_statuses, -> (object) { where("created_at > ?", object.updated_at) }, :class_name => 'FillStatus'
  #has_one :captcha_action, :class_name => 'CongressMemberAction', :condition => "value = '$CAPTCHA_SOLUTION'"

  serialize :success_criteria, LegacySerializer

  RECENT_FILL_IMAGE_BASE = 'https://img.shields.io/badge/'
  RECENT_FILL_IMAGE_EXT = '.svg'

  def self.bioguide bioguide_id
    find_by_bioguide_id bioguide_id
  end

  def self.with_existing_bioguide bioguide_id
    yield find_by_bioguide_id bioguide_id
  end

  def self.with_new_bioguide bioguide_id
    yield self.create :bioguide_id => bioguide_id
  end

  def self.with_new_or_existing_bioguide bioguide_id
    yield self.find_or_create_by bioguide_id: bioguide_id
  end

  def has_captcha?
    !actions.find_by_value("$CAPTCHA_SOLUTION").nil?
  end

  def recent_fill_status
    statuses = recent_fill_statuses
    {
      successes: statuses.success.count,
      errors: statuses.error.count,
      failures: statuses.failure.count
    }
  end

  def self.to_hash cm_array
    cm_hash = {}
    cm_array.each do |cm|
      cm_hash[cm.id.to_s] = cm
    end
    cm_hash
  end

  def self.retrieve_cached cm_hash, cm_id
    return cm_hash[cm_id] if cm_hash.include? cm_id
    cm_hash[cm_id] = self.find(cm_id)
  end

  def self.list_with_job_count cm_array
    members_ordered = cm_array.order(:bioguide_id)
    cms = members_ordered.as_json(only: :bioguide_id)

    jobs = Delayed::Job.where(queue: "error_or_failure")

    cm_hash = self.to_hash members_ordered
    people = DelayedJobHelper::tabulate_jobs_by_member jobs, cm_hash

    people.each do |bioguide, jobs_count|
      cms.select{ |cm| cm["bioguide_id"] == bioguide }.each do |cm|
        cm["jobs"] = jobs_count
      end
    end
    cms.to_json
  end
end


