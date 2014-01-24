require 'spec_helper'

describe "Main controller" do
  it "should return 200 status for index" do
    get '/'
    expect(last_response.status).to eq(200)
  end

  it "should not raise an exception for nonexistent congress members when requesting form elements for /retrieve-form-elements" do
    expect do
      post_json :'retrieve-form-elements', {"bio_ids" => ["B000243", "D000563"]}.to_json
    end.not_to raise_exception
    expect(JSON.load(last_response.body)).to eq({})
  end

  it "should retrieve form elements successfully for /retrieve-form-elements" do
    c = create :congress_member_with_actions
    post_json :'retrieve-form-elements', {"bio_ids" => [c.bioguide_id]}.to_json
    expect(JSON.load(last_response.body)[c.bioguide_id]).not_to be_nil
  end

  it "should retrieve form elements successfully with multiple congress members for /retrieve-form-elements" do
    c = create :congress_member_with_actions
    c2 = create :congress_member_with_actions, bioguide_id: "A111111"
    post_json :'retrieve-form-elements', {"bio_ids" => [c.bioguide_id, c2.bioguide_id]}.to_json

    last_response_json = JSON.load(last_response.body)
    expect(last_response_json[c.bioguide_id]).not_to be_nil
    expect(last_response_json[c2.bioguide_id]).not_to be_nil
  end
end
