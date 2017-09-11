class NotifySender
  attr_reader :congress_member, :sender_fields

  def initialize(congress_member, fields)
    @congress_member = congress_member
    @sender_fields = fields
  end

  def contact_url
    congress_member.contact_url || congress_member.actions.find_by!(action: "visit").value
  end

  def sender_email
    sender_fields["$EMAIL"]
  end

  def sender_message
    sender_fields["$MESSAGE"]
  end

  def sender_name
    if sender_fields["$NAME_PREFIX"].present?
      %(#{sender_fields["$NAME_PREFIX"]} #{sender_fields["$NAME_SUFFIX"]})
    else
      %(#{sender_fields["$NAME_FIRST"]} #{sender_fields["$NAME_LAST"]})
    end.strip
  end

  def execute
    this = self
    CongressForms::App.email do
      @name = this.sender_name
      @message = this.sender_message
      @contact_url = this.contact_url

      if this.congress_member.chamber == "house"
        @congress_member = "Representative #{this.congress_member.name}"
      else
        @congress_member = "Senator #{this.congress_member.name}"
      end

      from SMTP_SETTINGS.fetch(:from)
      to this.sender_email
      subject "Your message to #{@congress_member} could not be delivered"

      content_type :html
      body render("undeliverable_notification")
    end
  end
end
