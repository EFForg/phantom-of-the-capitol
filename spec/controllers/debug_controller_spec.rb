require 'spec_helper'

describe "Debug controller" do
  describe "route /recent-statuses-detailed" do
    it "should not be accessable without a correct debug_key" do
      get '/recent-statuses-detailed/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a bioguide is not found" do
      get '/recent-statuses-detailed/Z010101', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "for a member with 2 fill statuses, one failure one success" do
      before do
        @c = create :congress_member, success_criteria: YAML.dump({"headers"=>{"status"=>200}, "body"=>{"contains"=>"Won't get me!"}}), updated_at: Time.now - 1.hour
        create :fill_status, congress_member: @c, status: "success"
        @failure_fill_status = create :fill_status_failure, congress_member: @c
        @c.delay(queue: "error_or_failure").fill_out_form MOCK_VALUES
        @last_job = Delayed::Job.last
        @last_job.attempts = 1
        @last_job.run_at = Time.now
        @last_job.last_error = "Some failure"
        @last_job.save
      end

      it "should return recent statuses in order of time, descending" do
        get '/recent-statuses-detailed/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json.first["status"]).to eq("failure")
        expect(last_response_json.second["status"]).to eq("success")
      end

      it "should give detailed recent statuses" do
        allow(Delayed::Job).to receive(:find).and_return(@last_job)
        get '/recent-statuses-detailed/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json.first["error"]).to eq(@last_job.last_error)
        expect(last_response_json.first["dj_id"]).to eq(YAML.load(@failure_fill_status.extra)[:delayed_job_id])
        expect(last_response_json.first["screenshot"]).to eq(YAML.load(@failure_fill_status.extra)[:screenshot])
      end
    end
  end

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
        create :congress_member, bioguide_id: "A010101"
        create :congress_member, bioguide_id: "B010101"
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
