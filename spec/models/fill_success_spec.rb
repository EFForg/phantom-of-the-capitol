require 'spec_helper'

describe FillSuccess do
  before do
    FillSuccess.new campaign_tag: "test"
  end

  it "should create a new campaign tag when initialized with new name " do
    expect(CampaignTag.last).not_to be_nil
  end

  it "should not create a new campaign tag when initialized with an existing name" do
    FillSuccess.new campaign_tag: "test"
    expect(CampaignTag.count).to eq(1)
  end
end
