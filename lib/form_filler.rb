class FormFiller

  delegate :bioguide_id, to: :rep
  attr_accessor :rep
  attr_reader :fields

  def initialize(rep, fields, campaign_tag=nil, session:nil)
    @fields = fields
    @campaign_tag = campaign_tag
    @rep = rep
    @session = session
  end

  def fill_out_form(action = nil, &block)
    preprocess_message_fields

    status_fields = { congress_member: @rep, status: "success", extra: {} }
    status_fields[:campaign_tag] = @campaign_tag unless @campaign_tag.nil?
    response_hash = FormFiller::Capybara.new(@rep, @fields, session: @session)
      .fill_out(action, &block)

    handle_failure(response_hash, status_fields)

    fill_status = FillStatus.create(status_fields)
    fill_status.save if RECORD_FILL_STATUSES

    fill_status
  end

  private

  def handle_failure(response_hash, status_fields)
    return if response_hash[:success]

    if response_hash[:exception]
      status_fields[:status] ="error"

      message = response_hash[:exception].message
      status_fields[:extra][:screenshot] = message[:screenshot] if message.is_a?(Hash)
    else
      status_fields[:status] = "failure"
    end

    status_fields[:extra][:screenshot] ||= response_hash[:screenshot]
  end

  def preprocess_message_fields
    @fields["$EMAIL"] = @fields["$EMAIL"].sub(/\+.*@/, '@')

    @fields["$PHONE"] ||= "000-000-0000"
    @fields["$ADDRESS_ZIP5"] ||= "00000"
    @fields["$ADDRESS_COUNTY"] ||= "Unknown"
    @fields["$ADDRESS_STATE_POSTAL_ABBREV"] ||= @rep.try(:state)

    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub(/\d+\s*%/){ |m| "#{m[0..-2]} percent" }
    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub('\w*&\w*', ' and ')

    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub("’", "'")
    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub("“", '"').gsub("”", '"')

    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub("—", '-')
    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub("–", '-')

    @fields["$MESSAGE"].gsub!('--', '-') while @fields["$MESSAGE"] =~ /--/

    @fields["$MESSAGE"] = @fields["$MESSAGE"].gsub(/[^-+\s\w,.!?$@:;()#&_\/"']/, '')
  end
end
