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

  ff = {}
  post :'fill-out-form' do
    bio_id = params["bio_id"]
    fields = params["fields"]
    uid = params["uid"]
    content_type :json

    c = CongressMember.bioguide(bio_id)
    return {status: "error", message: "Congress member with provided bio id not found"}.to_json if c.nil?

    ff[uid] = FillHandler.new(c).fill fields
    ff_result = ff[uid].resume
    return {status: "captcha_needed", url: ff_result}.to_json unless ff_result == true or ff_result == false

    return {status: "error"}.to_json unless ff_result
    {status: "success"}.to_json
  end

  post :'fill-out-captcha' do
    uid = params["uid"]
    answer = params["answer"]

    content_type :json

    ff_result = ff[uid].resume answer
    return {status: "error"}.to_json unless ff_result
    {status: "success"}.to_json
  end
end
