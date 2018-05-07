FactoryGirl.define do
  factory :congress_member_action do
    congress_member
    action CongressMemberAction::ACTIONS.sample
  end
end
