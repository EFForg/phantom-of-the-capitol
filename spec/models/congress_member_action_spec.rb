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
end
