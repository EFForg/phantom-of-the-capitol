CongressForms::App.controller do
  get :index do
    render :index
  end

  post :'retrieve-form-elements' do
    bio_ids = params["bio_ids"]
    response = {}
    bio_ids.each do |bio_id|
      response[bio_id] = CongressMember.bioguide(bio_id).as_required_json
    end
    content_type :json
    response.to_json
  end
end
