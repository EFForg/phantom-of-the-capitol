require 'spec_helper'

describe FillStatus do
  before do
    FillStatus.new campaign_tag: "test"
  end

  it "should create a new campaign tag when initialized with new name " do
    expect(CampaignTag.last).not_to be_nil
  end

  it "should not create a new campaign tag when initialized with an existing name" do
    FillStatus.new campaign_tag: "test"
    expect(CampaignTag.count).to eq(1)
  end

  it "should deserialize the `extra` field successfully using YAML" do
    fs = create :fill_status, extra: {'some_info' => true}
    expect { YAML.load(fs.extra) }.not_to raise_error
  end
end
