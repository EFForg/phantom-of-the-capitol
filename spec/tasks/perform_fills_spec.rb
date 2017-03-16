require "spec_helper"

describe PerformFills do
  let(:fields){ MOCK_VALUES }
  let(:overrides){ { "$NAME_LAST" => "abc" } }
  let(:campaign_tag){ "rspec" }
  let(:congress_member){ create :congress_member_with_actions_and_captcha }
  let(:job){ congress_member.delay(queue: "error_or_failure").fill_out_form fields, campaign_tag }

  describe ".execute" do
    it "should call #run_job for each job's congress member, and destroy the job afterwards" do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

      task = PerformFills.new([job])
      expect(task).to receive(:run_job).with(job)

      fsj = double
      expect(FillStatusesJob).to receive(:find_by){ fsj }
      expect(fsj).to receive(:destroy)
      expect(job).to receive(:destroy)

      task.execute
    end

    context "regex was given" do
      it "should call #run_job if congress member's bioguide matches the regex" do
        allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

        task = PerformFills.new([job])
        expect(task).to receive(:run_job).with(job)
        task.execute
      end

      it "shouldn't call #run_job if congress member's bioguide does not match the regex" do
        allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

        task = PerformFills.new([job], regex: /^$/)
        expect(task).not_to receive(:run_job).with(job)
        task.execute
      end
    end
  end

  describe ".run_job" do
    it "should call #fill_out_form on the congress member, passing args and respecting overrides" do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

      expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag)

      task = PerformFills.new([job], overrides: overrides)
      task.run_job(job)
    end

    it "should swallow exceptions" do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

      expect(congress_member).to receive(:fill_out_form){ raise ArgumentError.new("oh no") }

      task = PerformFills.new([job], overrides: overrides)
      expect{ task.run_job(job) }.not_to raise_exception
    end

    context "recaptcha: true" do
      it "should call #fill_out_form_with_watir instead" do
        allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

        expect(congress_member).to receive(:fill_out_form_with_watir).with(fields.merge(overrides))

        task = PerformFills.new([job], overrides: overrides)
        task.run_job(job, recaptcha: true)
      end
    end

    context "block is given" do
      it "should pass block through to CongressMember#fill_out_form" do
        allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }

        block = Proc.new{}

        expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag, &block)

        task = PerformFills.new([job], overrides: overrides)
        task.run_job(job, &block)
      end
    end
  end
end
