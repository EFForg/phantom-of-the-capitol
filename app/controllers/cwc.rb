
require "cwc"

CongressForms::App.controller do
  get "cwc/:office_code/fields" do
    cm = CongressMember.find_by_cwc_office_code(params[:office_code])
    cm.as_cwc_required_json.to_json
  end

  post "cwc/:office_code/messages" do
    content_type :json

    cm = CongressMember.find_by_cwc_office_code(params[:office_code])
    return { status: "error", message: "Congress member with provided bio id not found" }.to_json if cm.nil?

    missing_parameters = []
    fields = params["fields"] || {}
    fields["$MESSAGE"] ||= fields["$STATEMENT"]
    cm.as_cwc_required_json[:required_actions].each do |field|
      unless fields.include?(field["value"])
        missing_parameters << field["value"]
      end
    end

    if missing_parameters.any?
      see_other = "/cwc/#{params[:office_code]}/fields"
      message = "Missing parameters (#{missing_parameters.join(', ')}). See #{see_other} for required parameters."
      return { status: "error", message: message }.to_json
    end

    begin
      if params["organization"]
        cm.message_via_cwc(fields, campaign_tag: params["campaign_tag"],
                           organization: { name: params["organization"] })
      else
        cm.message_via_cwc(fields, campaign_tag: params["campaign_tag"])
      end
      { status: "success" }.to_json
    rescue Cwc::BadRequest => e
      logger.warn("Cwc::BadRequest:")
      e.errors.each{ |error| logger.warn("  * #{error}") }
      { status: "error" }.to_json
    end
  end
end
