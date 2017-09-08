class NotifySender
  attr_reader :delayed_job

  def initialize(delayed_job)
    @delayed_job = delayed_job
  end

  def contact_url
    congress_member.actions.find_by!(action: "visit").value
  end

  def sender_email
    sender_fields["$EMAIL"]
  end

  def sender_message
    sender_fields["$MESSAGE"]
  end

  def sender_name
    sender_fields["$NAME_FIRST"]
  end

  def sender_fields
    handler.args[0]
  end

  def congress_member
    handler.object.reload
  end

  def handler
    @handler ||= YAML.load(delayed_job.handler)
  end

  def execute
    this = self
    CongressForms::App.email do
      @name = this.sender_name
      @message = this.sender_message
      @contact_url = this.contact_url
      @congress_member = this.congress_member.bioguide_id

      from SMTP_SETTINGS.fetch(:user_name)
      to this.sender_email
      subject "Your recent message to Congress #{rand}"

      content_type :html
      body render("undeliverable_notification")
    end
  end
end
