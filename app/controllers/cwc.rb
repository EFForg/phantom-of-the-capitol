
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

    cwc_client = Cwc::Client.new
    message = cwc_client.create_message(
      campaign_id: params["campaign_tag"] || SecureRandom.hex(16),

      recipient: { member_office: params["office_code"] },

      constituent: {
        prefix:		fields["$NAME_PREFIX"],
        first_name:	fields["$NAME_FIRST"],
        last_name:	fields["$NAME_FIRST"],
        address:	Array(fields["$ADDRESS_STREET"]),
        city:		fields["$ADDRESS_CITY"],
        state_abbreviation: fields["$ADDRESS_STATE_POSTAL_ABBREV"],
        zip:		fields["$ADDRESS_ZIP5"],
        email:		fields["$EMAIL"]
      },

      message: {
        subject: fields["$SUBJECT"],
        library_of_congress_topics: Array(fields["$TOPIC"]),
        constituent_message: fields["$MESSAGE"]
      }
    )

    begin
      cwc_client.deliver(message)

      if RECORD_FILL_STATUSES
        status_fields = {
          congress_member: cm,
          status: "success",
          extra: {}
        }

        if params["campaign_tag"]
          status_fields.merge!(campaign_tag: params["campaign_tag"])
        end

        FillStatus.create(status_fields)
      end

      { status: "success" }.to_json
    rescue Cwc::BadRequest => e
      logger.warn("Cwc::BadRequest:")
      e.errors.each{ |error| logger.warn("  * #{error}") }
      { status: "error" }.to_json
    end
  end
end
