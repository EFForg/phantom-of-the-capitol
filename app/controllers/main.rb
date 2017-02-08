require 'securerandom'

CongressForms::App.controller do

  get :index do
    render :index
  end

  before do
    response.headers['X-Backend-Hostname'] = Socket.gethostname
  end

  post :'retrieve-form-elements' do
    content_type :json
    return {status: "error", message: "You must provide bio_ids to retrieve form elements."}.to_json unless params.include? "bio_ids" and params["bio_ids"].is_a? Array

    bio_ids = params["bio_ids"]
    response = {}
    bio_ids.each do |bio_id|
      c = CongressMember.bioguide(bio_id)
      next if c.nil?

      if cwc_office_supported?(c.cwc_office_code)
        response[bio_id] = c.as_cwc_required_json
      else
        response[bio_id] = c.as_required_json
      end
    end
    response.to_json
  end

  fh = FillHash.new
  post :'fill-out-form' do
    content_type :json
    return {status: "error", message: "You must provide a bio_id and fields to fill out form."}.to_json unless params.include? "bio_id" and params.include? "fields"

    bio_id = params["bio_id"]
    fields = params["fields"]

    c = CongressMember.bioguide(bio_id)
    return {status: "error", message: "Congress member with provided bio id not found"}.to_json if c.nil?

    handler = FillHandler.new(c)
    result = handler.fill fields, params["campaign_tag"]
    result[:uid] = SecureRandom.hex
    fh[result[:uid]] = handler if result[:status] == "captcha_needed"
    result.to_json
  end

  post :'fill-out-captcha' do
    content_type :json
    requires_uid_and_answer params, "fill out captcha"

    return {status: "error", message: "The unique id provided was not found."}.to_json unless fh.include? @uid

    result = fh[@uid].fill_captcha @answer
    fh.delete(@uid) if result[:status] != "captcha_needed"
    result.to_json
  end

  get :'recent-fill-status/:bio_id' do
    content_type :json
    requires_bio_id params, "recent fill status"

    @c.recent_fill_status.to_json
  end

  get :'recent-fill-image/:bio_id' do
    content_type :json
    response.headers['Cache-Control'] = "no-cache"
    return {status: "error", message: "You must provide a bio_id to request the recent fill image."}.to_json unless params.include? "bio_id"

    bio_id = params["bio_id"]
    c = CongressMember.bioguide(bio_id)
    redirect to(CongressMember::RECENT_FILL_IMAGE_BASE + 'YAML-not%20found-red' + CongressMember::RECENT_FILL_IMAGE_EXT) if c.nil?

    fill_status = c.recent_fill_status

    if [fill_status[:successes], fill_status[:errors], fill_status[:failures]].max == 0
      redirect to(CongressMember::RECENT_FILL_IMAGE_BASE + 'not-tried-lightgray' + CongressMember::RECENT_FILL_IMAGE_EXT), 302
    else
      success_rate = fill_status[:successes].to_f / (fill_status[:successes] + fill_status[:errors] + fill_status[:failures])

      darkness = 0.8

      red = (1 - ([success_rate - 0.5, 0].max * 2)) * 255 * darkness
      green = [success_rate * 2, 1].min * 255 * darkness
      blue = 0

      color_hex = sprintf("%02X%02X%02X", red, green, blue)
      redirect to(CongressMember::RECENT_FILL_IMAGE_BASE + 'success-' + (success_rate * 100).to_i.to_s + '%-' + color_hex + CongressMember::RECENT_FILL_IMAGE_EXT), 302
    end
  end


  before :'fill-out-form' do
    if params["bio_id"] && (cm = CongressMember.bioguide(params["bio_id"]))
      if cwc_office_supported?(cm.cwc_office_code)
        status, headers, body = call env.merge("PATH_INFO" => "/cwc/#{cm.cwc_office_code}/messages")
        halt status, headers, body
      end
    end
  end
end
