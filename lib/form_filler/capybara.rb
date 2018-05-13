class FormFiller::Capybara
  include FormFiller::AssetsHelper

  CAPTCHA_SOLUTION = "$CAPTCHA_SOLUTION"

  delegate :bioguide_id, to: :rep

  def initialize(rep, fields, session: nil)
    @fields = fields
    @rep = rep
    @session = session
  end

  def fill_out(starting_action = nil, &block)
    @session ||= Capybara::Session.new(:poltergeist)
    @session.driver.options[:js_errors] = false
    @session.driver.options[:phantomjs_options] = ['--ssl-protocol=TLSv1']
    form_fill_log("begin")

    begin
      actions = @rep.actions.order(:step)

      if starting_action
        actions = actions.drop_while{ |a| a.id != starting_action.id }
      end

      actions.each do |a|
        action = FormFiller::CapybaraAction.new(a, @session, @fields)
        log_action(action)

        if action.value == CAPTCHA_SOLUTION
          yield(url_for(action), @session, @rep) unless @fields[CAPTCHA_SOLUTION]
          @session.find(action.selector).set(@fields[CAPTCHA_SOLUTION])
        else
          action.execute(&block)
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
      raise e
    ensure
      @session.driver.quit unless @rep.persist_session?
    end
  end

  def rep
    @rep
  end

  def fields
    @fields
  end

  private

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
    log_message = "#{@rep.bioguide_id} fill (#{[@rep.bioguide_id, @fields].hash.to_s(16)}): #{message}" << " #{message.try(:message)}"
    Padrino.logger.info(log_message)

    Raven.extra_context(fill_log: "") unless Raven.context.extra.key?(:fill_log)
    Raven.context.extra[:fill_log] << message << "\n"
  end
end
