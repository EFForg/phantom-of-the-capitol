require 'benchmark'

require 'spec_helper'
require 'thin'

describe "Main controller" do
  describe "running the Padrino app on an actual server" do
    before do
      Thread.new do
        Thin::Logging.silent = true
        Rack::Handler::Thin.run CongressForms::App.new, :Port => 9922, threaded: true
      end
      sleep 1
    end

    it "should run through the entire workflow for a captcha form successfully" do
      @c = create :congress_member_with_actions_and_captcha
      fill_out_form_response = Typhoeus.post(
        "localhost:9922/fill-out-form",
        method: :post,
        body: {
          bio_id: @c.bioguide_id,
          fields: MOCK_VALUES
        }.to_json,
        headers: { :'Content-Type' => "application/json" }
      )

      @uid = JSON.load(fill_out_form_response.body)["uid"]

      captcha_response = Typhoeus.post(
        "localhost:9922/fill-out-captcha",
        method: :post,
        body: {
          uid: @uid,
          answer: "placeholder"
        }.to_json,
        headers: { :'Content-Type' => "application/json" }
      )
      expect(captcha_response.code).to eq(200)
      expect(JSON.load(captcha_response.body)["status"]).to eq("success")
    end

    it "should perform some basic benchmarks" do
      if ENV["PADRINO_TEST_LOAD"] == "true"
        @c = create :congress_member_with_actions
        requests_arr = [10, 25, 50]

        requests_arr.each do |requests_num|
          result = Benchmark.realtime do
            threads = []
            1.upto(requests_num) do |i|
              threads << Thread.new do
                @uid = SecureRandom.hex(13)
                Typhoeus.post(
                  "localhost:9922/fill-out-form",
                  method: :post,
                  body: {
                    bio_id: @c.bioguide_id,
                    uid: @uid,
                    fields: MOCK_VALUES
                  }.to_json,
                  headers: { :'Content-Type' => "application/json" }
                )
                ActiveRecord::Base.connection.close
              end
            end
            threads.each do |t|
              t.join
            end
          end
          puts requests_num.to_s + " requests take " + result.to_s + " seconds to perform"
        end
      end
    end
  end

  it "should receive 200 status from index" do
    get '/'
    expect(last_response.status).to eq(200)
  end

  describe "route /retrieve-from-elements" do
    before do
      @route = '/retrieve-form-elements'
    end

    it "should not raise an exception for nonexistent congress members" do
      expect do
        post_json @route, {"bio_ids" => ["B000243", "D000563"]}.to_json
      end.not_to raise_exception
      expect(JSON.load(last_response.body)).to eq({})
    end

    it "should retrieve form elements successfully" do
      c = create :congress_member_with_actions
      post_json @route, {"bio_ids" => [c.bioguide_id]}.to_json
      expect(JSON.load(last_response.body)[c.bioguide_id]).not_to be_nil
    end

    it "should retrieve form elements successfully with multiple congress members" do
      c = create :congress_member_with_actions
      c2 = create :congress_member_with_actions, bioguide_id: "A111111"
      post_json @route, {"bio_ids" => [c.bioguide_id, c2.bioguide_id]}.to_json

      last_response_json = JSON.load(last_response.body)
      expect(last_response_json[c.bioguide_id]).not_to be_nil
      expect(last_response_json[c2.bioguide_id]).not_to be_nil
    end

    it "should return json indicating an error when trying retrieve fields without bio_ids or when bio_ids is not an array" do
      post_json @route, {}.to_json

      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
      expect(last_response_json["message"]).not_to be_nil # don't be brittle

      post_json @route, {"bio_ids" => "test"}.to_json

      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
      expect(last_response_json["message"]).not_to be_nil # don't be brittle
    end
  end

  describe "route /fill-out-form" do
    before do
      @route = '/fill-out-form'
      @campaign_tag = "know your rights"
    end

    it "should return json indicating an error when trying to fill out form for an undefined congress member" do
      post_json @route, {
        "bio_id" => "TEST",
        "fields" => MOCK_VALUES
      }.to_json
      expect(JSON.load(last_response.body)["status"]).to eq("error")
      expect(JSON.load(last_response.body)["message"]).not_to be_nil # don't be brittle
    end

    it "should return json indicating an error when trying to fill out form without fields" do
      c = create :congress_member_with_actions
      post_json @route, {
        "bio_id" => c.bioguide_id
      }.to_json
      last_response_json = JSON.load(last_response.body)

      expect(last_response_json["status"]).to eq("error")
      expect(last_response_json["message"]).to include("missing fields")
    end

    it "should return json indicating an error and create a new Delayed Job when trying to fill out form of CongressMember with incorrect success criteria" do
      c = create :congress_member_with_actions, success_criteria: YAML.dump({"headers"=>{"status"=>200}, "body"=>{"contains"=>"Won't get me!"}})
      post_json @route, {
        "bio_id" => c.bioguide_id,
        "fields" => MOCK_VALUES
      }.to_json
      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
      expect(last_response_json["message"]).not_to be_nil # don't be brittle
      expect(Delayed::Job.count).to eq(1)
    end

    it "should fill out a form when provided with the required values" do
      c = create :congress_member_with_actions
      post_json @route, {
        "bio_id" => c.bioguide_id,
        "fields" => MOCK_VALUES
      }.to_json
      expect(last_response.status).to eq(200)
      expect(JSON.load(last_response.body)["status"]).to eq("success")
      expect(FillStatus.success.count).to eq(1)
    end

    it "should all but fill out a form when provided with the required values and test=1" do
      c = create :congress_member_with_actions

      expect(CongressMember).to receive(:bioguide){ c }.at_least(:once)
      expect(c).not_to receive(:delay)
      expect(c).not_to receive(:fill_out_form)

      post_json @route, {
        "bio_id" => c.bioguide_id,
        "fields" => MOCK_VALUES,
        "test" => "1"
      }.to_json

      expect(last_response.status).to eq(200)
      expect(JSON.load(last_response.body)["status"]).to eq("success")
    end

    it "should create a new campaign tag record when filling in a form successfully with a campaign tag specified" do
      c = create :congress_member_with_actions
      post_json @route, {
        "bio_id" => c.bioguide_id,
        "fields" => MOCK_VALUES,
        "campaign_tag" => @campaign_tag
      }.to_json

      expect(last_response.status).to eq(200)
      expect(JSON.load(last_response.body)["status"]).to eq("success")
      expect(CampaignTag.last.name).to eq(@campaign_tag)
    end

    it "should 403 Forbidden when #preprocess_message is defined and returns false" do
      expect_any_instance_of(CongressForms::App).to receive(:preprocess_message){ false }

      c = create :congress_member_with_actions
      post_json @route, {
        "bio_id" => c.bioguide_id,
        "fields" => MOCK_VALUES,
        "campaign_tag" => @campaign_tag
      }.to_json

      expect(last_response.status).to eq(403)
    end

    describe "with a captcha" do
      before do
        c = create :congress_member_with_actions_and_captcha
        post_json @route, {
          "bio_id" => c.bioguide_id,
          "fields" => MOCK_VALUES
        }.to_json

        @uid = JSON.load(last_response.body)["uid"]

      end

      it "should result in a status of 'captcha_needed'" do
        expect(last_response.status).to eq(200)
        expect(JSON.load(last_response.body)["status"]).to eq("captcha_needed")
      end

      it "should result in 'success' with the right answer given" do
        post_json '/fill-out-captcha', {
          "uid" => @uid,
          "answer" => "placeholder"
        }.to_json
        expect(last_response.status).to eq(200)
        expect(JSON.load(last_response.body)["status"]).to eq("success")
      end

      it "should result in 'error' with the wrong answer given" do
        post_json '/fill-out-captcha', {
          "uid" => @uid,
          "answer" => "wrong"
        }.to_json
        expect(last_response.status).to eq(200)
        expect(JSON.load(last_response.body)["status"]).to eq("error")
      end

      it "should destroy the thread after giving a answer" do
        post_json '/fill-out-captcha', {
          "uid" => @uid,
          "answer" => "placeholder"
        }.to_json
        post_json '/fill-out-captcha', {
          "uid" => @uid,
          "answer" => "placeholder"
        }.to_json
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("error")
        expect(last_response_json["message"]).to eq("The unique id provided was not found.")
      end

      it "should destroy the thread after a time interval" do
        sleep(6)
        post_json '/fill-out-captcha', {
          "uid" => @uid,
          "answer" => "placeholder"
        }.to_json
        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("error")
        expect(last_response_json["message"]).to eq("The unique id provided was not found.")
      end
      
      it "should return json indicating an error without uid or answer" do
        post_json @route, {"answer" => "placeholder"}.to_json

        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("error")
        expect(last_response_json["message"]).not_to be_nil # don't be brittle

        post_json @route, {"uid" => @uid}.to_json

        last_response_json = JSON.load(last_response.body)
        expect(last_response_json["status"]).to eq("error")
        expect(last_response_json["message"]).not_to be_nil # don't be brittle
      end
    end 
  end

  describe "route /recent-fill-image" do
    describe "for member with 50% success rate" do
      before do
        c = create :congress_member_with_actions, bioguide_id: "A010101", updated_at: Time.now - 1.hour
        create :fill_status, congress_member: c, status: "success" 
        create :fill_status, congress_member: c, status: "error" 
      end

      it "should issue a 302 redirect to a shield image with a 50% success rate" do
        get '/recent-fill-image/A010101'
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to eq(CongressMember::RECENT_FILL_IMAGE_BASE + 'success-50%25-CCCC00' + CongressMember::RECENT_FILL_IMAGE_EXT)
      end
    end

    describe "for nonexistant member" do
      it "should issue a 302 redirect to a red shield displaying 'YAML-not found'" do
        get '/recent-fill-image/A010101'
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to eq(CongressMember::RECENT_FILL_IMAGE_BASE + 'YAML-not%20found-red' + CongressMember::RECENT_FILL_IMAGE_EXT)
      end
    end

    describe "for member without fills" do
      before do
        create :congress_member_with_actions, bioguide_id: "A010101"
      end

      it "should issue a 302 redirect to a gray shield displaying 'not tried'" do
        get '/recent-fill-image/A010101'
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to eq(CongressMember::RECENT_FILL_IMAGE_BASE + 'not-tried-lightgray' + CongressMember::RECENT_FILL_IMAGE_EXT)
      end
    end
  end

  describe "route /recent-fill-status" do
    describe "for member with one success and one error" do
      before do
        c = create :congress_member_with_actions, bioguide_id: "A010101", updated_at: Time.now - 1.hour
        create :fill_status, congress_member: c, status: "success" 
        create :fill_status, congress_member: c, status: "error" 
      end

      it "should return a json object with the correct " do
        get '/recent-fill-status/A010101'
        last_response_json = JSON.load(last_response.body)
        expect(last_response.status).to eq(200)
        expect(last_response_json["successes"]).to eq(1)
        expect(last_response_json["errors"]).to eq(1)
        expect(last_response_json["failures"]).to eq(0)
      end
    end

    describe "for nonexistant member" do
      it "should return an error" do
        get '/recent-fill-status/A010101'
        last_response_json = JSON.load(last_response.body)
        expect(last_response.status).to eq(200)
        expect(last_response_json["status"]).to eq("error")
        expect(last_response_json["message"]).to eq("Congress member with provided bio id not found")
      end
    end
  end
end
