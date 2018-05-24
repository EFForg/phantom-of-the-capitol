require 'spec_helper'

describe CongressMember do
  it "can be created" do
    expect {
      create :congress_member, bioguide_id: "B010101"
    }.to change(CongressMember, :count)

    expect(CongressMember.last.bioguide_id).to eq("B010101")
  end

  describe "that already exists" do
    let(:rep) { create(:congress_member, bioguide_id: "B010101") }

    it "can be updated" do
      rep.update(bioguide_id: "C010101")

      expect(rep.reload.bioguide_id).to eq("C010101")
    end

    it "should deserialize the `success_criteria` field successfully using YAML" do
      expect { YAML.load(rep.success_criteria) }.not_to raise_error
    end
  end

  describe "has_captcha?" do
    let(:rep) { create(:congress_member, bioguide_id: "B010101") }
    subject { rep.has_captcha? }

    it { is_expected.to be_falsey }

    context "with a solved captcha" do
      before do
        create(:congress_member_action, congress_member: rep, value: CAPTCHA_SOLUTION)
      end

      it { is_expected.to be_truthy }
    end
  end
end
