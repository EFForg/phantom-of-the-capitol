module FormFilling
  extend ActiveSupport::Concern
  CAPTCHA_SOLUTION = "$CAPTCHA_SOLUTION"

  included do
    attr_accessor :persist_session
    alias_method :persist_session?, :persist_session
  end

  def fill_out_form f={}, ct = nil, session: nil, action: nil, &block
    preprocess_message_fields(bioguide_id, f)

    status_fields = { congress_member: self, status: "success", extra: {} }
    status_fields[:campaign_tag] = ct unless ct.nil?
    response_hash = fill_out_form_with_capybara(
      f, session, starting_action: action, &block
    )

    handle_failure(response_hash, status_fields)

    fill_status = FillStatus.create(status_fields)
    fill_status.save if RECORD_FILL_STATUSES

    fill_status
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
        log_action(a, f)

        if a.value == CAPTCHA_SOLUTION
          yield(url_for(session, a), session, self) unless f[CAPTCHA_SOLUTION]
          session.find(a.selector).set(f[CAPTCHA_SOLUTION])
        else
          a.execute(session, f, &block)
        end
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

  def as_required_json o={}
    as_json({
      :only => [],
      :include => {:required_actions => CongressMemberAction::REQUIRED_JSON}
    }.merge o)
  end

  private

  def url_for(session, action)
    location =  CAPTCHA_LOCATIONS.fetch(bioguide_id, nil)
    location ||= session.driver.evaluate_script(
      'document.querySelector("' + action.captcha_selector.gsub('"', '\"') + '").getBoundingClientRect();'
    )
    self.class.save_captcha_and_store_poltergeist(
      session, location["left"], location["top"], location["width"], location["height"]
    )
  end

  def log_action(a, f)
    a_info = [a.selector.try(:inspect), a.value.inspect].compact.join(', ')
    form_fill_log(f, "#{a.action}(#{a_info})")
  end

  def check_success body_text
    criteria = YAML.load(success_criteria)
    # TODO: check headers
    body = criteria.fetch("body", nil)
    body && body_text.include?(body["contains"])
  end

  def form_fill_log(fields, message)
    log_message = "#{bioguide_id} fill (#{[bioguide_id, fields].hash.to_s(16)}): #{message}"
    Padrino.logger.info(log_message)

    Raven.extra_context(fill_log: "") unless Raven.context.extra.key?(:fill_log)
    Raven.context.extra[:fill_log] << message << "\n"
  end

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
