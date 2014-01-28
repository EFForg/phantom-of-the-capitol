CongressForms::App.controller do
  get :index do
    render :index
  end

  post :'retrieve-form-elements' do
    bio_ids = params["bio_ids"]
    response = {}
    bio_ids.each do |bio_id|
      c = CongressMember.bioguide(bio_id)
      response[bio_id] = c.as_required_json unless c.nil?
    end
    content_type :json
    response.to_json
  end

  fh = {}
  post :'fill-out-form' do
    bio_id = params["bio_id"]
    fields = params["fields"]
    uid = params["uid"]
    content_type :json

    c = CongressMember.bioguide(bio_id)
    return {status: "error", message: "Congress member with provided bio id not found"}.to_json if c.nil?

    handler = FillHandler.new(c)
    result = handler.fill fields
    fh[uid] = handler if result[:status] == "captcha_needed"
    result.to_json
  end

  post :'fill-out-captcha' do
    uid = params["uid"]
    answer = params["answer"]

    content_type :json

    return {status: "error", message: "The unique id provided was not found."}.to_json unless fh.include? uid

    result = fh[uid].fill_captcha answer
    fh.delete(uid)
    result.to_json
  end
end
