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
end
