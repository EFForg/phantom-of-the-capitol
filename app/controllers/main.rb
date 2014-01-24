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

  post :'fill-out-form' do
    bio_id = params["bio_id"]
    fields = params["fields"]
    content_type :json

    c = CongressMember.bioguide(bio_id)
    return {status: "error", message: "Congress member with provided bio id not found"}.to_json if c.nil?
    fill_succeeded = c.fill_out_form fields

    return {status: "error"}.to_json unless fill_succeeded
    {status: "success"}.to_json
  end
end
