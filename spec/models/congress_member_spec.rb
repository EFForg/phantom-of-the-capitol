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
end
