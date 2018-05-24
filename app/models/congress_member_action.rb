class CongressMemberAction < ActiveRecord::Base
  extend Enumerize

  ACTIONS = %w(visit fill_in select click_on find check uncheck choose wait javascript recaptcha)

  validates_presence_of :action

  belongs_to :congress_member

  serialize :options, LegacySerializer
  enumerize :action, in: ACTIONS
  scope :solved_captchas, -> { where(value: CAPTCHA_SOLUTION) }
end
