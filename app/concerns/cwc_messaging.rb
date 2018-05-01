require_dependency 'cwc/fixtures'

module CwcMessaging
  extend ActiveSupport::Concern

  def as_cwc_required_json o={}
    Cwc::RequiredJson.merge(o)
  end

  def message_via_cwc(fields, campaign_tag: nil, organization: nil,
                              message_type: :constituent_message, validate_only: false)
    cwc_client = Cwc::Client.new
    params = {
      campaign_id: campaign_tag || SecureRandom.hex(16),

      recipient: { member_office: cwc_office_code },

      constituent: {
        prefix:		fields["$NAME_PREFIX"],
        first_name:	fields["$NAME_FIRST"],
        last_name:	fields["$NAME_LAST"],
        address:	Array(fields["$ADDRESS_STREET"]),
        city:		fields["$ADDRESS_CITY"],
        state_abbreviation: fields["$ADDRESS_STATE_POSTAL_ABBREV"],
        zip:		fields["$ADDRESS_ZIP5"],
        email:		fields["$EMAIL"]
      },

      message: {
        subject: fields["$SUBJECT"],
        library_of_congress_topics: Array(fields["$TOPIC"])
      }
    }

    if organization
      params[:organization] = organization
    end

    if fields["$STATEMENT"]
      params[:message][:organization_statement] = fields["$STATEMENT"]
    end

    if fields["$MESSAGE"] && fields["$MESSAGE"] != fields["$STATEMENT"]
      params[:message][:constituent_message] = fields["$MESSAGE"]
    end

    message = cwc_client.create_message(params)

    if validate_only
      cwc_client.validate(message)
    else
      cwc_client.deliver(message)
      if RECORD_FILL_STATUSES
        status_fields = {
          congress_member: self,
          status: "success",
          extra: {}
        }

        if campaign_tag
          status_fields.merge!(campaign_tag: campaign_tag)
        end

        FillStatus.create(status_fields)
      end
    end
  end

  def cwc_office_code
    #it should not raise an exception if we can't get a code here, so this return will trigger a fallback to legacy forms
    return "" if chamber.nil?
    if chamber == "senate"
      sprintf("S%s%02d", state, senate_class-1)
    else
      sprintf("H%s%02d", state, house_district)
    end
  end

  class_methods do
    def find_by_cwc_office_code(code)
      cwco = Cwc::Office.new(code)

      # We should always load the latest congress member,
      # since there might be more than one as reps change seats.
      if cwco.senate?
        where(state: cwco.state, senate_class: cwco.senate_class).
          order("id desc").first
      else
        where(state: cwco.state, house_district: cwco.house_district).
          order("id desc").first
      end
    end
  end
end
