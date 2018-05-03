FactoryGirl.define do
  factory :congress_member do
    sequence(:bioguide_id){ |n| sprintf("A%06d", n) }
    success_criteria({"headers"=>{"status"=>200}, "body"=>{"contains"=>"Thank you for your feedback!"}})

    state "CA"
    chamber "house"
    house_district "12"

    factory :congress_member_with_actions_parent do
      after(:create) do |c|
        create :congress_member_action, action: "fill_in", name: 'zip', selector: '#zip', value: "$ADDRESS_ZIP5", required: true, step: 2, congress_member: c    
        create :congress_member_action, action: "find", selector: '#first-name', step: 3, congress_member: c
        create :congress_member_action, action: "fill_in", name: 'first-name', selector: '#first-name', value: "$NAME_FIRST", required: true, step: 4, congress_member: c
        create :congress_member_action, action: "fill_in", name: 'last-name', selector: '#last-name', value: "$NAME_LAST", required: true, step: 5, congress_member: c
        create :congress_member_action, action: "fill_in", name: 'address', selector: '#address', value: "$ADDRESS_STREET", required: true, step: 6, congress_member: c
        create :congress_member_action, action: "fill_in", name: 'city', selector: '#city', value: "$ADDRESS_CITY", required: true, step: 7, congress_member: c
        create :congress_member_action, action: "fill_in", name: 'email', selector: '#email', value: "$EMAIL", required: true, step: 8, congress_member: c
        create :congress_member_action, action: "check", name: 'email-opt-in', selector: '#email-opt-in', step: 9, congress_member: c
        create :congress_member_action, action: "uncheck", name: 'email-opt-out', selector: '#email-opt-out', step: 10, congress_member: c
        create :congress_member_action, action: "choose", name: 'favorite-color', selector: 'input[name=favorite-color][value=green]', step: 11, congress_member: c
        create :congress_member_action, action: "fill_in", name: 'message', selector: '#message', value: "$MESSAGE", required: true, step: 12, congress_member: c
        create :congress_member_action, action: "select", name: 'prefix', selector: '#prefix', value: "$NAME_PREFIX", required: true, step: 13, congress_member: c
      end

      factory :congress_member_with_actions do
        after(:create) do |c|
          create :congress_member_action, action: "visit", value: "http://localhost:3002/", step: 1, congress_member: c
          create :congress_member_action, action: "click_on", selector: 'input[type=submit]', value: "send", step: 14, congress_member: c
        end
      end

      factory :congress_member_with_actions_and_captcha do
        after(:create) do |c|
          create :congress_member_action, action: "visit", value: "http://localhost:3002/with-captcha", step: 1, congress_member: c
          create :congress_member_action, action: "fill_in", selector: "#captcha", captcha_selector: "#captcha-image", value: "$CAPTCHA_SOLUTION", step: 14, congress_member: c
          create :congress_member_action, action: "click_on", selector: 'input[type=submit]', value: "send", step: 15, congress_member: c
        end
      end
    end
  end

  factory :congress_member_action do
    congress_member
  end

  factory :fill_statuses_job do
    fill_status
  end

  factory :fill_status do
    congress_member
    campaign_tag
    status "success"

    factory :fill_status_failure do
      status "failure"
      extra({ screenshot: "https://www.example.com/blah.png" })

      factory :fill_status_failure_with_delayed_job do
        after(:create) do |fs|
          fs.congress_member.delay(queue: "error_or_failure").fill_out_form MOCK_VALUES
          job = Delayed::Job.last
          job.attempts = 1
          job.run_at = Time.now
          job.last_error = "Some failure"
          job.save
          fs.extra = { screenshot: "https://www.example.com/blah.png" }
          fs.save
          create :fill_statuses_job, fill_status_id: fs.id, delayed_job_id: job.id
        end
      end
    end
  end
  
  factory :campaign_tag do
    name "test"
  end
end
