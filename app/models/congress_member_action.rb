class CongressMemberAction < ActiveRecord::Base
  validates_presence_of :action

  REQUIRED_JSON = {
    :only => [
      :value,
      :maxlength
    ],
    :methods => [:options_hash]
  }

  belongs_to :congress_member

  extend Enumerize

  enumerize :action, in: %w(visit fill_in select click_on find check uncheck choose)

  def as_required_json o={}
    as_json(REQUIRED_JSON.merge o)
  end

  def options_hash
    return nil if options.nil?
    YAML.load(options)
  end
end
