require 'securerandom'
require 'cwc/fixtures'

CongressForms::App.controller do
  helpers CwcHelper

  get :index do
    render :index
  end

  before do
    Raven.tags_context web: true
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
        response[bio_id] = Cwc::RequiredJson
      else
        response[bio_id] = c.as_required_json(only: [:defunct, :contact_url])
      end
    end

    response.to_json
  end

  fh = FillHash.new
  post :'fill-out-form' do
    content_type :json

    return {status: "error", message: "You must provide a bio_id."}.to_json unless params.include? "bio_id"

    bio_id = params["bio_id"]
    c = CongressMember.bioguide(bio_id)
    return {status: "error", message: "Congress member with provided bio id not found"}.to_json if c.nil?

    missing_parameters = []
    fields = params["fields"] || {}
    c.as_required_json["required_actions"].each do |field|
      unless fields.include?(field["value"])
        missing_parameters << field["value"]
      end
    end

    if missing_parameters.any?
      message = "Error: missing fields (#{missing_parameters.join(', ')})."
      return { status: "error", message: message }.to_json
    end

    if params["test"] == "1"
      return { status: "success", test: true }.to_json
    end

    handler = FillHandler.new(c, fields, params["campaign_tag"])
    result = handler.fill
    result[:uid] = SecureRandom.hex
    fh[result[:uid]] = handler if result[:status] == "captcha_needed"

    if result[:status] == "error"
      Raven.capture_message("Form error: #{bio_id}", tags: { "form_error" => true })

      job = c.delay(queue: "error_or_failure").fill_out_form(fields, params["campaign_tag"])

      if RECORD_FILL_STATUSES
        fill_status = FillStatus.find(result[:fill_status_id])
        FillStatusesJob.create(fill_status_id: fill_status.id, delayed_job_id: job.id)
      end
    end

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
      redirect to(CongressMember::RECENT_FILL_IMAGE_BASE + 'success-' + (success_rate * 100).to_i.to_s + '%25-' + color_hex + CongressMember::RECENT_FILL_IMAGE_EXT), 302
    end
  end

  before :'fill-out-form' do
    if respond_to?(:preprocess_message) && preprocess_message(request, params["bio_id"], params["fields"]) == false
      halt 403, {}, "Access Denied"
    end

    if params["bio_id"] && (cm = CongressMember.bioguide(params["bio_id"]))
      if cwc_office_supported?(cm.cwc_office_code)
        status, headers, body = call env.merge("PATH_INFO" => "/cwc/#{cm.cwc_office_code}/messages")
        halt status, headers, body
      end
    end
  end
end
