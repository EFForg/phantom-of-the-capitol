require 'spec_helper'

describe CongressMemberAction do
  it "should not be created without an action specified" do
    expect do
      create :congress_member_action, action: nil
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should not be created with an invalid action specified" do
    expect do
      create :congress_member_action, action: "testing"
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should deserialize the `options` field successfully using YAML" do
    ca = create :congress_member_action, action: "select", name: "topic", options: {'agriculture' => "AG", 'economy' => "EC"}
    expect { YAML.load(ca.options) }.not_to raise_error
  end

  describe "#solved_captcha" do
    let!(:captcha_action) do
      create(:congress_member_action, value: CAPTCHA_SOLUTION)
    end
    let!(:random_action) do
      create(:congress_member_action, value: "$ADDRESS")
    end

    it "returns only CAPTCHA_SOLUTION actions" do
      expect(described_class.solved_captchas).to match_array([captcha_action])
    end
  end
end
