class CongressMemberAction < ActiveRecord::Base
  belongs_to :congress_member

  extend Enumerize

  enumerize :action, in: %w(visit fill_in select click_on find check uncheck choose)
end
