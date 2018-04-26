require "spec_helper"

describe PerformFills do
  let(:fields){ MOCK_VALUES }
  let(:overrides){ { "$NAME_LAST" => "abc" } }
  let(:campaign_tag){ "rspec" }
  let(:congress_member){ create :congress_member_with_actions_and_captcha }
  let(:job){ congress_member.delay(queue: "error_or_failure").fill_out_form fields, campaign_tag }

  describe ".execute" do
    before do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

      allow_any_instance_of(Object).to receive(:to_i){ 0 }
    end

    it "should call #run_job for each job's congress member, and destroy the job afterwards if successful" do
      task = PerformFills.new([job])
      expect(task).to receive(:run_job).with(job){ true }

      expect(DelayedJobHelper).to receive(:destroy_job_and_dependents).with(job)

      task.execute
    end

    it "should call #run_job for each job's congress member, and preserve the job afterwards if it failed" do
      task = PerformFills.new([job])
      expect(task).to receive(:run_job).with(job){ false }

      expect(DelayedJobHelper).not_to receive(:destroy_job_and_dependents)

      task.execute
    end

    it "should process jobs in the right order" do
      captcha_job = double("captcha_job")
      noncaptcha_job = double("noncaptcha_job")

      task = PerformFills.new([])
      expect(task).to receive(:filter_jobs){ [[captcha_job], [noncaptcha_job]] }

      expect(task).to receive(:run_job).with(captcha_job).ordered
      expect(task).to receive(:run_job).with(noncaptcha_job).ordered
      allow(DelayedJobHelper).to receive(:destroy_job_and_dependents)

      task.execute
    end

    context "regex was given" do
      it "should call #run_job if congress member's bioguide matches the regex" do
        task = PerformFills.new([job])
        expect(task).to receive(:run_job).with(job)
        task.execute
      end

      it "shouldn't call #run_job if congress member's bioguide does not match the regex" do
        task = PerformFills.new([job], regex: /^$/)
        expect(task).not_to receive(:run_job).with(job)
        task.execute
      end
    end
  end

  describe "#run_job" do
    before do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, anything){ congress_member }
      allow_any_instance_of(PerformFills).to receive(:cwc_office_supported?){ false }
    end

    it "should call #fill_out_form on the congress member, passing args and respecting overrides" do
      expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag).
                                  and_return(FillStatus.new(status: "success"))

      task = PerformFills.new([job], overrides: overrides)
      task.run_job(job)
    end

    it "should call #preprocess_job if defined and not proceed if false" do
      task = PerformFills.new([job], overrides: overrides)

      expect(task).to receive(:preprocess_job){ false }
      expect_any_instance_of(CongressMember).not_to receive(:message_via_cwc)
      expect_any_instance_of(CongressMember).not_to receive(:fill_out_form)

      task.run_job(job)
    end

    context "congress member is supported by Cwc" do
      it "should call #message_via_cwc instead" do
        expect(congress_member).to receive(:message_via_cwc).with(fields.merge(overrides), campaign_tag: campaign_tag)

        task = PerformFills.new([job], overrides: overrides)
        expect(task).to receive(:cwc_office_supported?).with(congress_member.cwc_office_code){ true }

        task.run_job(job)
      end
    end

    context "block is given" do
      it "should pass block through to CongressMember#fill_out_form" do
        block = Proc.new{}

        expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag, &block).
                                    and_return(FillStatus.new(status: "success"))

        task = PerformFills.new([job], overrides: overrides)
        task.run_job(job, &block)
      end
    end
  end

  describe "#filter_jobs" do
    it "should partition jobs into captcha, and noncaptcha" do
      captcha_cm = create :congress_member_with_actions_and_captcha
      noncaptcha_cm = create :congress_member_with_actions

      jobs = [captcha_cm, noncaptcha_cm].map do |cm|
        cm.delay(queue: "error_or_failure").fill_out_form fields, campaign_tag
      end

      captcha_jobs = [jobs[0]]
      noncaptcha_jobs = [jobs[1]]

      task = PerformFills.new(jobs)
      expect(task.filter_jobs).to eq([captcha_jobs, noncaptcha_jobs])
    end
  end
end
