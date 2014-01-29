CongressForms::App.controller do
  get :index do
    render :index
  end

  post :'retrieve-form-elements' do
    content_type :json
    return {status: "error", message: "You must provide bio_ids to retrieve form elements."}.to_json unless params.include? "bio_ids" and params["bio_ids"].is_a? Array

    bio_ids = params["bio_ids"]
    response = {}
    bio_ids.each do |bio_id|
      c = CongressMember.bioguide(bio_id)
      response[bio_id] = c.as_required_json unless c.nil?
    end
    response.to_json
  end

  fh = FillHash.new
  post :'fill-out-form' do
    content_type :json
    return {status: "error", message: "You must provide a bio_id, fields, and a uid to fill out form."}.to_json unless params.include? "bio_id" and params.include? "fields" and params.include? "uid"

    bio_id = params["bio_id"]
    fields = params["fields"]
    uid = params["uid"]

    c = CongressMember.bioguide(bio_id)
    return {status: "error", message: "Congress member with provided bio id not found"}.to_json if c.nil?

    handler = FillHandler.new(c)
    result = handler.fill fields
    fh[uid] = handler if result[:status] == "captcha_needed"
    result.to_json
  end

  post :'fill-out-captcha' do
    content_type :json
    return {status: "error", message: "You must provide a uid and answer to fill out captcha."}.to_json unless params.include? "uid" and params.include? "answer"

    uid = params["uid"]
    answer = params["answer"]

    return {status: "error", message: "The unique id provided was not found."}.to_json unless fh.include? uid

    result = fh[uid].fill_captcha answer
    fh.delete(uid)
    result.to_json
  end
end
