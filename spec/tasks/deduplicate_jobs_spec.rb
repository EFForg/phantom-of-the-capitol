require "spec_helper"

describe DeduplicateJobs do
  def make_job(cm, fields={}, campaign_tag="rspec")
    cm.delay(queue: "error_or_failure").fill_out_form(MOCK_VALUES.merge(fields), campaign_tag)
  end

  let(:jobs){ Delayed::Job.where(queue: "error_or_failure") }
  let(:congress_member1){ create :congress_member_with_actions_and_captcha }
  let(:congress_member2){ create :congress_member_with_actions_and_captcha }

  describe ".execute" do
    it "should do nothing to messages directed at different legislators" do
      make_job(congress_member1)
      make_job(congress_member2)

      expect(jobs.count).to eq(2)
      DeduplicateJobs.new(jobs).execute
      expect(jobs.count).to eq(2)
    end

    it "should do nothing to messages to the same legislator with differing fields" do
      make_job(congress_member1, "$NAME_FIRST" => "Jack")
      make_job(congress_member1, "$NAME_FIRST" => "Jill")

      expect(jobs.count).to eq(2)
      DeduplicateJobs.new(jobs).execute
      expect(jobs.count).to eq(2)
    end

    it "should deduplicate messages to the same legislator with the same fields, keeping the earliest version" do
      job1 = make_job(congress_member1, MOCK_VALUES)
      job2 = make_job(congress_member1, MOCK_VALUES)
      job2.update(created_at: Time.now-1.day)

      expect(jobs.count).to eq(2)
      DeduplicateJobs.new(jobs).execute
      expect(jobs.count).to eq(1)

      expect(jobs.reload.take).to eq(job2)
    end
  end
end
