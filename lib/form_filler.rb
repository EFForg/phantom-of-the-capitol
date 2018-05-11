class FormFiller
  CAPTCHA_SOLUTION = "$CAPTCHA_SOLUTION"

  delegate :bioguide_id, to: :rep

  def initialize(rep, fields, campaign_tag=nil, session:nil)
    @fields = fields
    @campaign_tag = campaign_tag
    @rep = rep
    @session = session
  end

  # TODO: move this into FillHandler and give the capybara stuff its own class?
  def fill_out_form(action = nil, &block)
    preprocess_message_fields

    status_fields = { congress_member: @rep, status: "success", extra: {} }
    status_fields[:campaign_tag] = @campaign_tag unless @campaign_tag.nil?
    response_hash = fill_out_form_with_capybara(starting_action: action, &block)

    handle_failure(response_hash, status_fields)

    fill_status = FillStatus.create(status_fields)
    fill_status.save if RECORD_FILL_STATUSES

    fill_status
  end

  def rep
    @rep
  end

  def fields
    @fields
  end

  private

  def fill_out_form_with_capybara(starting_action: nil, &block)
    @session ||= Capybara::Session.new(:poltergeist)
    @session.driver.options[:js_errors] = false
    @session.driver.options[:phantomjs_options] = ['--ssl-protocol=TLSv1']
    form_fill_log("begin")

    begin
      actions = @rep.actions.order(:step)

      if starting_action
        actions = actions.drop_while{ |a| a.id != starting_action.id }
      end

      actions.each do |action|
        log_action(action)

        if action.value == CAPTCHA_SOLUTION
          yield(url_for(action), @session, @rep) unless @fields[CAPTCHA_SOLUTION]
          @session.find(action.selector).set(@fields[CAPTCHA_SOLUTION])
        else
          action.execute(@session, @fields, &block)
        end
      end

      success = check_success @session.text
      form_fill_log("done: #{success ? 'passing' : 'failing'} success criteria")

      success_hash = {success: success}
      success_hash[:screenshot] = save_screenshot_and_store_poltergeist if !success
      success_hash
    rescue Exception => e
      form_fill_log("done: unsuccessful fill (#{e.class})")
      Raven.extra_context(backtrace: e.backtrace)

      message = {success: false, message: e.message, exception: e}
      message[:screenshot] = save_screenshot_and_store_poltergeist
      message
    ensure
      @session.driver.quit unless @rep.persist_session?
    end
  end

  def url_for(action)
    location =  CAPTCHA_LOCATIONS.fetch(@rep.bioguide_id, nil)
    location ||= @session.driver.evaluate_script(
      'document.querySelector("' + action.captcha_selector.gsub('"', '\"') + '").getBoundingClientRect();'
    )
    save_captcha_and_store_poltergeist(
      location["left"], location["top"], location["width"], location["height"]
    )
  end

  def log_action(a)
    a_info = [a.selector.try(:inspect), a.value.inspect].compact.join(', ')
    form_fill_log("#{a.action}(#{a_info})")
  end

  def check_success body_text
    criteria = YAML.load(@rep.success_criteria)
    # TODO: check headers
    body = criteria.fetch("body", nil)
    body && body_text.include?(body["contains"])
  end

  def form_fill_log(message)
    log_message = "#{@rep.bioguide_id} fill (#{[@rep.bioguide_id, @fields].hash.to_s(16)}): #{message}"
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

  def save_screenshot_and_store_poltergeist
    screenshot_location = random_screenshot_location
    @session.save_screenshot(screenshot_location, full: true)
    url = store_screenshot_from_location screenshot_location
    Raven.extra_context(screenshot: url)
    File.unlink screenshot_location
    url
  end

  def save_captcha_and_store_poltergeist x, y, width, height
    screenshot_location = random_captcha_location
    @session.save_screenshot(screenshot_location, full: true)
    crop_screenshot_from_coords screenshot_location, x, y, width, height
    url = store_captcha_from_location screenshot_location
    File.unlink screenshot_location
    url
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

  def random_captcha_location
    "#{Padrino.root}/public/captchas/#{SecureRandom.hex(13)}.png"
  end

  def random_screenshot_location
    "#{Padrino.root}/public/screenshots/#{SecureRandom.hex(13)}.png"
  end
end
