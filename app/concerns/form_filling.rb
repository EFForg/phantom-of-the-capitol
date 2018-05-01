module FormFilling
  extend ActiveSupport::Concern

  included do
    attr_accessor :persist_session
    alias_method :persist_session?, :persist_session
  end

  def fill_out_form f={}, ct = nil, session: nil, action: nil, &block
    preprocess_message_fields(bioguide_id, f)

    status_fields = {
      congress_member: self,
      status: "success",
      extra: {}
    }
    status_fields[:campaign_tag] = ct unless ct.nil?

    success_hash = fill_out_form_with_capybara f, session, starting_action: action, &block

    unless success_hash[:success]
      status_fields[:status] = success_hash[:exception] ? "error" : "failure"
      status_fields[:extra][:screenshot] = success_hash[:screenshot]

      if success_hash[:exception]
        message = YAML.load(success_hash[:exception].message)

        if message.is_a?(Hash) and message.include?(:screenshot)
          status_fields[:extra][:screenshot] = message[:screenshot]
        end
      end
    end

    fill_status = FillStatus.create(status_fields)
    fill_status.save if RECORD_FILL_STATUSES

    fill_status
  end

  def fill_out_form!(f={}, ct=nil, &block)
    fill_out_form(f, ct, &block)[0] or raise FillError.new
  end

  def fill_out_form_with_capybara f, session=nil, starting_action: nil, &block
    session ||= Capybara::Session.new(:poltergeist)
    session.driver.options[:js_errors] = false
    session.driver.options[:phantomjs_options] = ['--ssl-protocol=TLSv1']
    form_fill_log(f, "begin")

    begin
      actions = self.actions.order(:step)

      if starting_action
        actions = actions.drop_while{ |a| a.id != starting_action.id }
      end

      actions.each do |a|
        form_fill_log(f, %(#{a.action}(#{a.selector.inspect+", " if a.selector.present?}#{a.value.inspect})))

        a.execute(session, self, f, &block)
      end

      success = check_success session.text
      form_fill_log(f, "done: #{success ? 'passing' : 'failing'} success criteria")

      success_hash = {success: success}
      success_hash[:screenshot] = self.class::save_screenshot_and_store_poltergeist(session) if !success
      success_hash
    rescue Exception => e
      form_fill_log(f, "done: unsuccessful fill (#{e.class})")
      Raven.extra_context(backtrace: e.backtrace)

      message = {success: false, message: e.message, exception: e}
      message[:screenshot] = self.class::save_screenshot_and_store_poltergeist(session)
      message
    ensure
      session.driver.quit unless persist_session?
    end
  end

  def check_success body_text
    criteria = YAML.load(success_criteria)
    criteria.each do |i, v|
      case i
      when "headers"
        v.each do |hi, hv|
          case hi
          when "status"
            # TODO: check status code
          end
        end
      when "body"
        v.each do |bi, bv|
          case bi
          when "contains"
            unless body_text.include? bv
              return false
            end
          end
        end
      end
    end
    true
  end

  def as_required_json o={}
    as_json({
      :only => [],
      :include => {:required_actions => CongressMemberAction::REQUIRED_JSON}
    }.merge o)
  end

  private

  def form_fill_log(fields, message)
    log_message = "#{bioguide_id} fill (#{[bioguide_id, fields].hash.to_s(16)}): #{message}"
    Padrino.logger.info(log_message)

    Raven.extra_context(fill_log: "") unless Raven.context.extra.key?(:fill_log)
    Raven.context.extra[:fill_log] << message << "\n"
  end

  public

  class_methods do
    def crop_screenshot_from_coords screenshot_location, x, y, width, height
      img = MiniMagick::Image.open(screenshot_location)
      img.crop width.to_s + 'x' + height.to_s + "+" + x.to_s + "+" + y.to_s
      img.write screenshot_location
    end

    def store_captcha_from_location location
      c = CaptchaUploader.new
      c.store!(File.open(location))
      c.url
    end

    def store_screenshot_from_location location
      s = ScreenshotUploader.new
      s.store!(File.open(location))
      s.url
    end

    def save_screenshot_and_store_poltergeist session
      screenshot_location = random_screenshot_location
      session.save_screenshot(screenshot_location, full: true)
      url = store_screenshot_from_location screenshot_location
      Raven.extra_context(screenshot: url)
      File.unlink screenshot_location
      url
    end

    def save_captcha_and_store_poltergeist session, x, y, width, height
      screenshot_location = random_captcha_location
      session.save_screenshot(screenshot_location, full: true)
      crop_screenshot_from_coords screenshot_location, x, y, width, height
      url = store_captcha_from_location screenshot_location
      File.unlink screenshot_location
      url
    end

    def random_captcha_location
      "#{Padrino.root}/public/captchas/#{SecureRandom.hex(13)}.png"
    end

    def random_screenshot_location
      "#{Padrino.root}/public/screenshots/#{SecureRandom.hex(13)}.png"
    end
  end
end
