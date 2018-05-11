FactoryGirl.define do
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
          FormFiller.new(fs.congress_member, MOCK_VALUES)
            .delay(queue: "error_or_failure").fill_out_form
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
end
