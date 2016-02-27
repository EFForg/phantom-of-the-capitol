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
        @failure_fill_status = create :fill_status_failure_with_delayed_job, congress_member: @c
      end

      it "should return recent statuses in order of time, descending" do
        get '/recent-statuses-detailed/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json.first["status"]).to eq("failure")
        expect(last_response_json.second["status"]).to eq("success")
      end

      it "should give detailed recent statuses" do
        get '/recent-statuses-detailed/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json.first["dj_id"]).to eq(@failure_fill_status.delayed_job.id)
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
        @c = create :congress_member, bioguide_id: "B010101"
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

      describe "with delayed jobs for one member" do
        before do
          5.times do
            create :fill_status_failure_with_delayed_job, congress_member: @c
          end
        end

        it "should give the number of delayed jobs per congress member" do
          get '/list-congress-members', { debug_key: DEBUG_KEY }
          last_response_json = JSON.load(last_response.body)
          expect(last_response_json.second["jobs"]).to eq(5)
        end
      end
    end
  end

  describe "route /successful-fills-by-date" do
    it "should not be accessable without a correct debug_key" do
      get '/successful-fills-by-date/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "for multiple members with fill statuses" do
      before do
        c = create :congress_member, bioguide_id: "A010101"
        c2 = create :congress_member, bioguide_id: "B010101"
        2.times do
          create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-01')
        end
        3.times do
          create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-02')
        end
        create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-03')
        create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-02'), campaign_tag: create(:campaign_tag, name: "test2")
        create :fill_status_failure, congress_member: c, status: "failure", created_at: Time.zone.parse('2015-01-02')
        create :fill_status_failure, congress_member: c2, status: "success", created_at: Time.zone.parse('2015-01-02')
      end

      it "should accurately select the number of successes for a given member" do
        get '/successful-fills-by-date/A010101', { debug_key: DEBUG_KEY, date_start: "2015-01-01", date_end: "2015-01-03" }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(2)
        expect(last_response_json[Time.zone.parse('2015-01-01').to_s]).to eq(2)
        expect(last_response_json[Time.zone.parse('2015-01-02').to_s]).to eq(4)
      end

      it "should accurately select the number of successes for every member" do
        get '/successful-fills-by-date/', { debug_key: DEBUG_KEY, date_start: "2015-01-01", date_end: "2015-01-03" }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(2)
        expect(last_response_json[Time.zone.parse('2015-01-01').to_s]).to eq(2)
        expect(last_response_json[Time.zone.parse('2015-01-02').to_s]).to eq(5)
      end

      it "should accurately select the number of successes for every member" do
        get '/successful-fills-by-date/', { debug_key: DEBUG_KEY, date_start: "2015-01-01", date_end: "2015-01-03", campaign_tag: "test2" }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(1)
        expect(last_response_json[Time.zone.parse('2015-01-02').to_s]).to eq(1)
      end
    end
  end

  describe "route /successful-fills-by-hour" do
    it "should not be accessable without a correct debug_key" do
      get '/successful-fills-by-hour/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "for multiple members with fill statuses" do
      before do
        c = create :congress_member, bioguide_id: "A010101"
        c2 = create :congress_member, bioguide_id: "B010101"
        2.times do
          create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-01 00:00:00')
        end
        3.times do
          create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-01 1:01:00')
        end
        create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-01 2:04:00')
        create :fill_status, congress_member: c, status: "success", created_at: Time.zone.parse('2015-01-01 1:02:00'), campaign_tag: create(:campaign_tag, name: "test2")
        create :fill_status_failure, congress_member: c, status: "failure", created_at: Time.zone.parse('2015-01-01 00:00:00')
        create :fill_status_failure, congress_member: c2, status: "success", created_at: Time.zone.parse('2015-01-01 1:53:00')
      end

      it "should accurately select the number of successes for a given member" do
        get '/successful-fills-by-hour/A010101', { debug_key: DEBUG_KEY, date: "2015-01-01", time_zone: Time.zone.name}
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(3)
        expect(last_response_json[Time.zone.parse('2015-01-01 00:00:00').to_s]).to eq(2)
        expect(last_response_json[Time.zone.parse('2015-01-01 01:00:00').to_s]).to eq(4)
      end

      it "should accurately select the number of successes for every member" do
        get '/successful-fills-by-hour/', { debug_key: DEBUG_KEY, date: "2015-01-01", time_zone: Time.zone.name}
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(3)
        expect(last_response_json[Time.zone.parse('2015-01-01 00:00:00').to_s]).to eq(2)
        expect(last_response_json[Time.zone.parse('2015-01-01 01:00:00').to_s]).to eq(5)
      end

      it "should accurately select the number of successes for every member" do
        get '/successful-fills-by-hour/', { debug_key: DEBUG_KEY, date: "2015-01-01", time_zone: Time.zone.name, campaign_tag: "test2" }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(1)
        expect(last_response_json[Time.zone.parse('2015-01-01 01:00:00').to_s]).to eq(1)
      end
    end
  end

  describe "route /successful-fills-by-member" do
    it "should not be accessable without a correct debug_key" do
      get '/successful-fills-by-member/', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "for multiple members with fill statuses" do
      before do
        c = create :congress_member, bioguide_id: "A010101"
        c2 = create :congress_member, bioguide_id: "B010101"
        3.times do
          create :fill_status, congress_member: c, status: "success"
        end
        create :fill_status, congress_member: c, status: "success", campaign_tag: create(:campaign_tag, name: "test2")
        create :fill_status_failure, congress_member: c, status: "failure"
        create :fill_status_failure, congress_member: c2, status: "success"
      end

      it "should accurately select the number of sucesses by member" do
        get '/successful-fills-by-member/', { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(2)
        expect(last_response_json['A010101']).to eq(4)
        expect(last_response_json['B010101']).to eq(1)
      end

      it "should accurately select the number of sucesses by member" do
        get '/successful-fills-by-member/', { debug_key: DEBUG_KEY, campaign_tag: "test2" }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.values.count).to eq(1)
        expect(last_response_json['A010101']).to eq(1)
      end

    end
  end

  describe "route /job-details" do
    it "should not be accessable without a correct debug_key" do
      get '/job-details/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a job id is not found" do
      get '/job-details/77', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "for multiple members with fill statuses" do
      before do
        @status = create :fill_status_failure_with_delayed_job
      end

      it "should provide the mock values" do
        get '/job-details/' + @status.delayed_job.id.to_s, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)

        MOCK_VALUES.keys.each do |k|
          expect(last_response_json['arguments'][0][k]).to eq(MOCK_VALUES[k])
        end
      end

      it "should provide the bioguide id" do
        get '/job-details/' + @status.delayed_job.id.to_s, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)

          expect(last_response_json['bioguide']).to eq(@status.congress_member.bioguide_id)
      end

    end
  end

  describe "route /list-jobs" do
    it "should not be accessable without a correct debug_key" do
      get '/list-jobs/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a bioguide is not found" do
      get '/list-jobs/Z010101', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "with a few jobs for a member" do
      before do
        @c = create :congress_member, bioguide_id: "B010101"
        5.times do
          create :fill_status_failure_with_delayed_job, congress_member: @c
        end

        @c2 = create :congress_member, bioguide_id: "A010101"
        2.times do
          create :fill_status_failure_with_delayed_job, congress_member: @c2
        end
      end

      it "should provide a list of job ids" do
        get '/list-jobs/' + @c.bioguide_id, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json.count).to eq(5)
      end
    end
  end

  describe "get /job-details" do
    it "should not be accessable without a correct debug_key" do
      get '/job-details/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a job id is not found" do
      get '/job-details/77', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "with a job" do
      before do
        @fill_status = create :fill_status_failure_with_delayed_job
      end

      it "should accurately provide job details" do
        job_id = @fill_status.delayed_job.id
        get '/job-details/' + job_id.to_s, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)

        expect(last_response_json['arguments'][0]).to eq(MOCK_VALUES)
        expect(last_response_json['bioguide']).to eq(@fill_status.congress_member.bioguide_id)
      end
    end
  end

  describe "put /job-details" do
    it "should not be accessable without a correct debug_key" do
      put '/job-details/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a job id is not found" do
      put '/job-details/77', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "with a job" do
      before do
        @fill_status = create :fill_status_failure_with_delayed_job
      end

      it "should successfully modify a job" do
        job_id = @fill_status.delayed_job.id
        arguments = [{
          "$NAME_FIRST" => "Testing",
          "$NAME_LAST" => "McTesterson"
        }]
        put_json '/job-details/' + job_id.to_s, {
          debug_key: DEBUG_KEY,
          arguments: arguments
        }.to_json
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("success")

        job = Delayed::Job.find(job_id)
        handler = YAML.load(job.handler)
        expect(handler.args).to eq(arguments)
      end
    end
  end

  describe "delete /job-details" do
    it "should not be accessable without a correct debug_key" do
      delete '/job-details/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a job id is not found" do
      delete '/job-details/77', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "with a job" do
      before do
        @fill_status = create :fill_status_failure_with_delayed_job
      end

      it "should successfully delete a job" do
        job_id = @fill_status.delayed_job.id
        delete '/job-details/' + job_id.to_s, { debug_key: DEBUG_KEY }

        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("success")
        expect{ Delayed::Job.find(job_id) }.to raise_error ActiveRecord::RecordNotFound
      end
    end
  end

  describe "options /job-details" do
    it "should respond with a 200 status code" do
      options '/job-details/doesnt_matter', { debug_key: DEBUG_KEY }
      expect(last_response.status).to eq(200)
    end
  end

  describe "route /perform-job" do
    it "should not be accessable without a correct debug_key" do
      get '/perform-job/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a job id is not found" do
      get '/perform-job/77', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "with a non-captcha job" do
      before do
        @fill_status = create :fill_status_failure_with_delayed_job, congress_member: create(:congress_member_with_actions)
      end

      it "should perform the job successfully" do
        job_id = @fill_status.delayed_job.id
        get '/perform-job/' + job_id.to_s, { debug_key: DEBUG_KEY }
        expect(last_response.status).to eq(200)
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("success")
        expect(FillStatus.success.count).to eq(1)
      end
    end

    describe "with a captcha job" do
      before do
        @fill_status = create :fill_status_failure_with_delayed_job, congress_member: create(:congress_member_with_actions_and_captcha)
      end

      it "should provide information that a captcha is needed and a uid" do
        job_id = @fill_status.delayed_job.id
        get '/perform-job/' + job_id.to_s, { debug_key: DEBUG_KEY }
        expect(last_response.status).to eq(200)
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("captcha_needed")
        expect(last_response_json["uid"].blank?).to be_falsy
      end
    end
  end

  describe "route /perform-job-captcha" do
    it "should not be accessable without a correct debug_key" do
      post '/perform-job-captcha/TEST', { debug_key: DEBUG_KEY + "cruft" }
      expect(last_response.status).to eq(401)
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    it "should return an error response when a job id is not found" do
      post '/perform-job-captcha/77', { debug_key: DEBUG_KEY }
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
    end

    describe "with a captcha job" do
      before do
        @fill_status = create :fill_status_failure_with_delayed_job, congress_member: create(:congress_member_with_actions_and_captcha)
      end

      it "should perform the job successfully" do
        job_id = @fill_status.delayed_job.id
        get '/perform-job/' + job_id.to_s, { debug_key: DEBUG_KEY }
        last_response_json = JSON.load(last_response.body)
        post '/perform-job-captcha/' + last_response_json["uid"], { debug_key: DEBUG_KEY, answer: "placeholder" }
        expect(last_response.status).to eq(200)
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("success")
      end
    end
  end
end
