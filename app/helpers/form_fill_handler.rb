require 'fiber'

class FillHandler
  def initialize c
    @c = c
  end

  def create_fiber fields={}
    @fiber = Fiber.new do |answer|
      begin
        @c.fill_out_form fields do |c|
          answer = Fiber.yield c
        end
      rescue
        false
      end
    end
  end

  def fill fields={}
    create_fiber fields
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
