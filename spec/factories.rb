FactoryGirl.define do
  factory :congress_member do
    bioguide_id "A000000"
    success_criteria YAML.dump({"headers"=>{"status"=>200}, "body"=>{"contains"=>"Thank you for your feedback!"}})
  end

  factory :congress_member_action do
  end

end
