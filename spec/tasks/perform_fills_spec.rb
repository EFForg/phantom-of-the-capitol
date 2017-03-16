require "spec_helper"

describe PerformFills do
  let(:fields){ MOCK_VALUES }
  let(:overrides){ { "$NAME_LAST" => "abc" } }
  let(:campaign_tag){ "rspec" }
  let(:congress_member){ create :congress_member_with_actions_and_captcha }
  let(:job){ congress_member.delay(queue: "error_or_failure").fill_out_form fields, campaign_tag }

  describe ".execute" do
    it "should call #fill_out_form on each job's congress member" do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }
      expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag)

      PerformFills.new([job], overrides: overrides).execute
    end

    it "should destroy each job when it's done" do
      allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }
      expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag)

      fsj = double
      expect(FillStatusesJob).to receive(:find_by){ fsj }
      expect(fsj).to receive(:destroy)
      expect(job).to receive(:destroy)

      PerformFills.new([job], overrides: overrides).execute
    end

    context "regex is given" do
      it "should call #fill_out_form if congress member's bioguide matches the regex" do
        allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }
        expect(congress_member).to receive(:fill_out_form).with(fields.merge(overrides), campaign_tag)

        bioguide = congress_member.bioguide_id
        pattern = /#{bioguide[0, 3]}/

        PerformFills.new([job], regex: pattern, overrides: overrides).execute
      end

      it "shouldn't call #fill_out_form if congress member's bioguide does not match the regex" do
        allow(CongressMember).to receive(:retrieve_cached).with(anything, congress_member.id.to_s){ congress_member }
        expect(congress_member).not_to receive(:fill_out_form)

        PerformFills.new([job], regex: /^$/, overrides: overrides).execute
      end
    end
  end
end
