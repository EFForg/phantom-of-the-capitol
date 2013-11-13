class CongressMemberField < ActiveRecord::Base
  extend Enumerize

  enumerize :field_type, in: %w(textarea textfield checkbox select)
end
