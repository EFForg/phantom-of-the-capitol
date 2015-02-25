require 'spec_helper'

describe "Debug controller" do
  describe "route /list-actions" do
    it "should not be accessable without a correct debug_key" do
      get '/list-actions/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a bioguide is not found" do
      get '/list-actions/Z010101', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "for a member with actions" do
      before do
        @c = create :congress_member_with_actions, bioguide_id: "A010101"
      end

      it "should return a 200 status" do
        get '/list-actions/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        expect(last_response.status).to eq(200)
      end

      it "should list the correct number of actions" do
        get '/list-actions/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["actions"].count).to eq(@c.actions.count)
      end
    end
  end

  describe "route /list-congress-members" do
    it "should not be accessable without a correct debug_key" do
      get '/list-congress-members', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(JSON.load(last_response.body)["status"]).to eq("error")
    end

    describe "with two members of congress" do
      before do
        create :congress_member_with_actions, bioguide_id: "A010101"
        create :congress_member_with_actions, bioguide_id: "B010101"
      end

      it "should return 200 status" do
        get '/list-congress-members', { debug_key: DEBUG_KEY }
        expect(last_response.status).to eq(200)
      end

      it "should list the correct number of congress members" do
        get '/list-congress-members', { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json.count).to eq(2)
      end

      it "should list congress members alphabetically by bioguide" do
        get '/list-congress-members', { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json.first["bioguide_id"]).to eq("A010101")
        expect(last_response_json.second["bioguide_id"]).to eq("B010101")
      end
    end
  end
end
