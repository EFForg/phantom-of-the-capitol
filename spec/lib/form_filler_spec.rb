require 'spec_helper'

describe FormFiller do
  let(:iterations) { 10 }
  let(:campaign_tag) { "" }
  let(:congress_member) do
    create :congress_member_with_actions, :bioguide_id => "B010101"
  end
  let(:form_filler) do
    described_class.new(congress_member, MOCK_VALUES, campaign_tag)
  end

  subject(:fill_out_form) do
    form_filler.fill_out_form
  end

  it "should return something truthy" do
    expect(fill_out_form).to be_truthy
  end

  it "should not increase the number of open files drastically" do
    before_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
    iterations.times { fill_out_form }
    after_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
    expect(after_of).to be < (before_of + iterations)
  end

  it "should add a success record to the FillStatus table" do
    expect { fill_out_form }.to change(FillStatus.success, :count).by(1)
  end

  context "when campaign tag is provided" do
    let(:campaign_tag) { "some campaign" }

    it "should return something truthy" do
      expect(fill_out_form).to be_truthy
    end

    it "should create a new tag" do
      expect { fill_out_form }.to change(CampaignTag, :count).by(1)
      expect(CampaignTag.last.name).to eq(campaign_tag)
    end
  end

  context "with a delay" do
    subject(:delay_fill) do
      described_class.new(congress_member, MOCK_VALUES).delay.fill_out_form
    end

    it "should delay filling out a form for a congress member" do
      delay_fill
      expect(Delayed::Worker.new.run Delayed::Job.last).to be_truthy
    end

    it "should not update the FillStatus table" do
      expect { delay_fill }.not_to change(FillStatus, :count)
    end
  end

  context "with an incorrect success criteria" do
    let(:congress_member) do
      create(
        :congress_member_with_actions,
        success_criteria: YAML.dump(
          {"headers"=>{"status"=>200}, "body"=>{"contains"=>"Won't get me!"}}
        )
      )
    end

    it "should return a failed FilledStatus" do
      expect(fill_out_form.success?).to be false
    end

    it "should add a failure record to the FillStatus table" do
      expect { fill_out_form }.to change(FillStatus.failure, :count).by(1)
    end

    it "should include a screenshot in the FillStatus" do
      fill_out_form
      expect(YAML.load(FillStatus.last.extra).include? :screenshot).to eq(true)
    end
  end

  describe "with captcha" do
    let(:congress_member) do
      create :congress_member_with_actions_and_captcha, :bioguide_id => "B010101"
    end

    it "should succeed" do
      expect(form_filler.fill_out_form { |c| "placeholder" }).to be_truthy
    end
  end
end
