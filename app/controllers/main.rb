require 'securerandom'
require 'cwc/fixtures'

CongressForms::App.controller do
  helpers CwcHelper

  before do
    Raven.tags_context web: true
    response.headers['X-Backend-Hostname'] = Socket.gethostname
  end

  before :'fill-out-form' do
    if respond_to?(:preprocess_message) && preprocess_message(request, params["bio_id"], params["fields"]) == false
      halt 403, {}, "Access Denied"
    end

    if params["bio_id"] && (cm = CongressMember.find_by(bioguide_id: params["bio_id"]))
      if cwc_office_supported?(cm.cwc_office_code)
        status, headers, body = call env.merge("PATH_INFO" => "/cwc/#{cm.cwc_office_code}/messages")
        halt status, headers, body
      end
    end
  end

  get :index do
    render :index
  end

  post :'retrieve-form-elements' do
    content_type :json
    return error_response("You must provide bio_ids to retrieve form elements.") unless params.include? "bio_ids" and params["bio_ids"].is_a? Array
    bio_ids = params["bio_ids"]

    response = {}
    bio_ids.each do |bio_id|
      c = CongressMember.find_by(bioguide_id: bio_id)
      next if c.nil?

      if cwc_office_supported?(c.cwc_office_code)
        response[bio_id] = Cwc::RequiredJson
      else
        response[bio_id] = c.as_required_json(only: [:defunct, :contact_url])
      end
    end

    response.to_json
  end

  post :'fill-out-form' do
    content_type :json

    return error_response("You must provide a bio_id.") unless params.include? "bio_id"

    bio_id = params["bio_id"]
    c = CongressMember.find_by(bioguide_id: bio_id)
    return error_response("Congress member with provided bio id not found") if c.nil?

    missing_parameters = []
    fields = params["fields"] || {}
    c.as_required_json["required_actions"].each do |field|
      unless fields.include?(field["value"])
        missing_parameters << field["value"]
      end
    end

    message = "Error: missing fields (#{missing_parameters.join(', ')})."
    return error_response(message) unless has_params(missing_parameters)

    if params["test"] == "1"
      return { status: "success", test: true }.to_json
    end

    handler = FillHandler.new(c, fields, params["campaign_tag"])
    result = handler.fill
    result[:uid] = SecureRandom.hex
    captcha_record[result[:uid]] = handler if result[:status] == "captcha_needed"

    if result[:status] == "error"
      Raven.capture_message("Form error: #{bio_id}", tags: { "form_error" => true })

      job = FormFiller.new(c, fields, params["campaign_tag"])
        .delay(queue: "error_or_failure").fill_out_form

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

    return error_response("The unique id provided was not found.") unless captcha_record.include? @uid

    result = captcha_record[@uid].fill_captcha @answer
    captcha_record.delete(@uid) if result[:status] != "captcha_needed"
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
    return error_response("You must provide a bio_id to request the recent fill image.") unless params.include? "bio_id"

    c = CongressMember.find_by(bioguide_id: params["bio_id"])
    redirect to(recent_fill_url('YAML-not%20found-red')) if c.nil?

    fill_status = c.recent_fill_status
    url = if [fill_status[:successes], fill_status[:errors], fill_status[:failures]].max == 0
      recent_fill_url('not-tried-lightgray')
    else
      success_rate = fill_status[:successes].to_f / (fill_status[:successes] + fill_status[:errors] + fill_status[:failures])
      recent_fill_url("success-#{(success_rate * 100).to_i}%25-#{success_color(success_rate)}")
    end

    redirect to(url), 302
  end

  define_method :captcha_record do
    @captcha_record ||= CaptchaCache.current
  end

  define_method :recent_fill_url do |options|
    CongressMember::RECENT_FILL_IMAGE_BASE + options + CongressMember::RECENT_FILL_IMAGE_EXT
  end
end
