require 'spec_helper'

describe CongressMemberAction do
  it "should not be created without an action specified" do
    expect do
      create :congress_member_action
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should not be created with an invalid action specified" do
    expect do
      create :congress_member_action, action: "testing"
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should only have the required fields when calling as_required_json" do
    ca = create :congress_member_action, action: "fill_in", name: "first-name", value: "first-name"
    expect(ca.as_json["id"]).not_to be_nil
    expect(ca.as_required_json["id"]).to be_nil
  end

  it "should deserialize the `options` field successfully using YAML" do
    ca = create :congress_member_action, action: "select", name: "topic", options: {'agriculture' => "AG", 'economy' => "EC"}
    expect { YAML.load(ca.options) }.not_to raise_error
  end
end
