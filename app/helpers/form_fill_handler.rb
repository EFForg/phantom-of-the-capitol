class FillHandler
  attr_reader :fields, :campaign_tag, :session, :saved_action

  def initialize c, fields, campaign_tag = "", debug = false
    @c = c
    @debug = debug
    @fields = fields
    @campaign_tag = campaign_tag
  end

  def fill(session=nil, action=nil)
    if DELAY_ALL_NONCAPTCHA_FILLS and not @c.has_captcha? and not @debug
      @c.delay(queue: "default").fill_out_form fields, campaign_tag
      result = true
    else
      fill_status = @c.fill_out_form(fields, campaign_tag, session: session) do |url, session, action|
        if fields["$CAPTCHA_SOLUTION"]
          fields["$CAPTCHA_SOLUTION"]
        else
          @session = session
          @saved_action = action
          @c.persist_session = true
          return {
            status: "captcha_needed",
            url: url
          }
        end
      end

      result = fill_status.success?
    end

    FillHandler::check_result result, fill_status.try(:id)
  end

  def finish_workflow
    fill_captcha ""
  end

  def fill_captcha answer
    fields.merge!("$CAPTCHA_SOLUTION" => answer)
    fill(session, saved_action)
  end

  def self.check_result result, fill_status_id = nil
    case result
    when true
      {status: "success", fill_status_id: fill_status_id}
    when false
      {status: "error", message: "An error has occurred while filling out the remote form.", fill_status_id: fill_status_id}
    end
  end
end

