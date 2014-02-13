require 'fiber'

class FillHandler
  def initialize c
    @c = c
  end

  def create_fiber fields={}, campaign_tag
    @fiber = Fiber.new do |answer|
      begin
        if DELAY_ALL_NONCAPTCHA_FILLS and not @c.has_captcha?
          @c.delay.fill_out_form fields, campaign_tag
          true
        else
          @c.fill_out_form fields, campaign_tag do |c|
            answer = Fiber.yield c
          end
        end
      rescue Exception => e
        # we need to add the job manually instead of delaying and running automatically above, since DJ doesn't handle yield blocks
        @c.delay.fill_out_form fields, campaign_tag
        last_job = Delayed::Job.last
        last_job.attempts = 1
        last_job.run_at = Time.now
        last_job.last_error = e.message + "\n" + e.backtrace.inspect
        last_job.save
        false
      end
    end
  end

  def fill fields={}, campaign_tag
    create_fiber fields, campaign_tag
    result = @fiber.resume
    FillHandler::check_result result
  end

  def fill_captcha answer
    return false unless @fiber
    result = @fiber.resume answer
    FillHandler::check_result result
  end

  def self.check_result result
    case result
    when true
      {status: "success"}
    when false
      {status: "error", message: "An error has occurred while filling out the remote form."}
    else
      {status: "captcha_needed", url: result}
    end
  end
end
