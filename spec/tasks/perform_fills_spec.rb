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
    end

    it "should call #run_job for each job's congress member, and destroy the job afterwards" do
      task = PerformFills.new([job])
      expect(task).to receive(:run_job).with(job)

      fsj = double
      expect(FillStatusesJob).to receive(:find_by){ fsj }
      expect(fsj).to receive(:destroy)
      expect(job).to receive(:destroy)

      task.execute
    end

    it "should process jobs in the right order" do
      recaptcha_jobs, captcha_jobs, noncaptcha_jobs = double, double, double

      task = PerformFills.new([])
      expect(task).to receive(:filter_jobs){ [recaptcha_jobs, captcha_jobs, noncaptcha_jobs] }

      expect(recaptcha_jobs).not_to receive(:each)
      expect(captcha_jobs).to receive(:each).ordered
      expect(noncaptcha_jobs).to receive(:each).ordered
      task.execute
    end

    context "recaptcha_mode: true" do
      it "should process only recaptcha jobs" do
        recaptcha_jobs, captcha_jobs, noncaptcha_jobs = double, double, double

        task = PerformFills.new([])
        expect(task).to receive(:filter_jobs){ [recaptcha_jobs, captcha_jobs, noncaptcha_jobs] }

        expect(recaptcha_jobs).to receive(:each)
        expect(captcha_jobs).not_to receive(:each)
        expect(noncaptcha_jobs).not_to receive(:each)
        task.execute(recaptcha_mode: true)
      end

      it "should call #run_job with recaptcha: true" do
        allow(DelayedJobHelper).to receive(:destroy_job_and_dependents)

        recaptcha_job = double

        task = PerformFills.new([])
        expect(task).to receive(:filter_jobs){ [[recaptcha_job], [], []] }
        expect(task).to receive(:run_job).with(recaptcha_job, recaptcha: true)
        task.execute(recaptcha_mode: true)
      end
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
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }
    end

    it "should call #fill_out_form on the congress member, passing args and respecting overrides" do
      expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag)

      task = PerformFills.new([job], overrides: overrides)
      task.run_job(job)
    end

    it "should swallow exceptions" do
      expect(congress_member).to receive(:fill_out_form){ raise ArgumentError.new("oh no") }

      task = PerformFills.new([job], overrides: overrides)
      expect{ task.run_job(job) }.not_to raise_exception
    end

    context "recaptcha: true" do
      it "should call #fill_out_form_with_watir instead" do
        expect(congress_member).to receive(:fill_out_form_with_watir).with(fields.merge(overrides))

        task = PerformFills.new([job], overrides: overrides)
        task.run_job(job, recaptcha: true)
      end
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

        expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag, &block)

        task = PerformFills.new([job], overrides: overrides)
        task.run_job(job, &block)
      end
    end
  end

  describe "#filter_jobs" do
    it "should partition jobs into recaptcha, captcha, and noncaptcha" do
      captcha_cm = create :congress_member_with_actions_and_captcha
      noncaptcha_cm = create :congress_member_with_actions
      recaptcha_cm = create :congress_member_with_actions_and_captcha
      recaptcha_cm.actions.where(value: "$CAPTCHA_SOLUTION").update_all(action: "recaptcha", value: nil)

      jobs = [captcha_cm, noncaptcha_cm, recaptcha_cm].map do |cm|
        cm.actions.reload
        cm.delay(queue: "error_or_failure").fill_out_form fields, campaign_tag
      end

      captcha_jobs = [jobs[0]]
      noncaptcha_jobs = [jobs[1]]
      recaptcha_jobs = [jobs[2]]

      task = PerformFills.new(jobs)
      expect(task.filter_jobs).to eq([recaptcha_jobs, captcha_jobs, noncaptcha_jobs])
    end
  end
end
