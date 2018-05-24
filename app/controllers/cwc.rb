require "cwc"

CongressForms::App.controller do
  before do
    Raven.tags_context web: true
    @cm = CongressMember.find_by_cwc_office_code(params[:office_code])
  end

  get "cwc/:office_code/fields" do
    Cwc::RequiredJson.to_json
  end

  post "cwc/:office_code/messages" do
    content_type :json

    return error_response("Congress member with provided bio id not found") if @cm.nil?

    fields = params["fields"] || {}
    fields["$MESSAGE"] ||= fields["$STATEMENT"]

    missing_parameters = Cwc::RequiredJson["required_actions"].map {|f| f["value"] } - fields.keys
    if missing_parameters.any?
      see_other = "/cwc/#{params[:office_code]}/fields"
      message = "Error: missing fields (#{missing_parameters.join(', ')}). See #{see_other} for required fields."
      return error_response(message)
    end

    keywords = { campaign_tag: params["campaign_tag"] }
    keywords[:organization] = { name: params["organization"] } if params["organization"]
    keywords[:validate_only] = true if params["test"] == "1"

    begin
      @cm.message_via_cwc(fields, **keywords)
      response = { status: "success" }
      response[:test] = true if params["test"] == "1"
      response.to_json
    rescue Cwc::BadRequest => e
      logger.warn("Cwc::BadRequest:")
      e.errors.each{ |error| logger.warn("  * #{error}") }

      Raven.capture_message("Cwc::BadRequest: #{e.errors.last}",
                            extra: { bioguide: @cm.bioguide_id, fields: fields, errors: e.errors })

      NotifySender.new(@cm, fields).delay(queue: "notifications").execute if SMTP_SETTINGS.present?

      { status: "error" }.to_json
    end
  end
end
