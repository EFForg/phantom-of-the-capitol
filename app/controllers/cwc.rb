require "cwc"

CongressForms::App.controller do
  before do
    Raven.tags_context web: true
  end

  get "cwc/:office_code/fields" do
    cm = CongressMember.find_by_cwc_office_code(params[:office_code])
    Cwc::RequiredJson.to_json
  end

  post "cwc/:office_code/messages" do
    content_type :json

    cm = CongressMember.find_by_cwc_office_code(params[:office_code])
    return { status: "error", message: "Congress member with provided bio id not found" }.to_json if cm.nil?

    missing_parameters = []
    fields = params["fields"] || {}
    fields["$MESSAGE"] ||= fields["$STATEMENT"]
    Cwc::RequiredJson["required_actions"].each do |field|
      unless fields.include?(field["value"])
        missing_parameters << field["value"]
      end
    end

    if missing_parameters.any?
      see_other = "/cwc/#{params[:office_code]}/fields"
      message = "Error: missing fields (#{missing_parameters.join(', ')}). See #{see_other} for required fields."
      return { status: "error", message: message }.to_json
    end

    keywords = { campaign_tag: params["campaign_tag"] }
    keywords[:organization] = { name: params["organization"] } if params["organization"]
    keywords[:validate_only] = true if params["test"] == "1"

    begin
      cm.message_via_cwc(fields, **keywords)
      if params["test"] == "1"
        { status: "success", test: true }.to_json
      else
        { status: "success" }.to_json
      end
    rescue Cwc::BadRequest => e
      logger.warn("Cwc::BadRequest:")
      e.errors.each{ |error| logger.warn("  * #{error}") }

      Raven.capture_message("Cwc::BadRequest: #{e.errors.last}",
                            extra: { bioguide: cm.bioguide_id, fields: fields, errors: e.errors })

      NotifySender.new(cm, fields).delay(queue: "notifications").execute if SMTP_SETTINGS.present?

      { status: "error" }.to_json
    end
  end
end
