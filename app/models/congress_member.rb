class CongressMember < ActiveRecord::Base
  validates_presence_of :bioguide_id

  has_many :actions, :class_name => 'CongressMemberAction', :dependent => :destroy
  has_many :required_actions, :class_name => 'CongressMemberAction', :conditions => "required = true AND SUBSTRING(value, 1, 1) = '$'"
  has_many :fill_statuses, :class_name => 'FillStatus', :dependent => :destroy
  has_many :recent_fill_statuses, :class_name => 'FillStatus', :conditions => proc{"created_at > '#{self.updated_at}'"}
  #has_one :captcha_action, :class_name => 'CongressMemberAction', :condition => "value = '$CAPTCHA_SOLUTION'"

  class FillFailure < Error
  end

  def self.bioguide bioguide_id
    find_by_bioguide_id bioguide_id
  end

  def self.with_existing_bioguide bioguide_id
    yield find_by_bioguide_id bioguide_id
  end

  def self.with_new_bioguide bioguide_id
    yield self.create :bioguide_id => bioguide_id
  end

  def self.with_new_or_existing_bioguide bioguide_id
    yield self.find_or_create_by_bioguide_id bioguide_id
  end

  def as_required_json o={}
    as_json({
      :only => [],
      :include => {:required_actions => CongressMemberAction::REQUIRED_JSON}
    }.merge o)
  end

  def fill_out_form f={}, ct = nil, &block
    status_fields = {congress_member: self, status: "success", extra: {}}.merge(ct.nil? ? {} : {campaign_tag: ct})
    begin
      begin
        success_hash = fill_out_form_with_poltergeist f, &block
      rescue Exception => e
        status_fields[:status] = "error"
        message = YAML.load(e.message)
        status_fields[:extra][:screenshot] = message[:screenshot] if message.is_a?(Hash) and message.include? :screenshot
        raise e, message[:message] if message.is_a?(Hash)
        raise e, message
      end

      unless success_hash[:success]
        status_fields[:status] = "failure"
        status_fields[:extra][:screenshot] = success_hash[:screenshot] if success_hash.include? :screenshot
        raise FillFailure, "Filling out the remote form was not successful"
      end
    rescue Exception => e
      # we need to add the job manually, since DJ doesn't handle yield blocks
      self.delay.fill_out_form f, ct
      last_job = Delayed::Job.last
      last_job.attempts = 1
      last_job.run_at = Time.now
      last_job.last_error = e.message + "\n" + e.backtrace.inspect
      last_job.save
      status_fields[:extra][:delayed_job_id] = last_job.id
      raise e
    ensure
      FillStatus.new(status_fields).save if RECORD_FILL_STATUSES
    end
    true
  end

  # it doesn't look like this method is ever called, but if it is used
  # later, we might want to implement the "wait" option for the "find"
  # directive (see fill_out_form_with_poltergeist)
  def fill_out_form_with_watir f={}
    b = Watir::Browser.new
    begin
      actions.order(:step).each do |a|
        case a.action
        when "visit"
          b.goto a.value
        when "fill_in"
          if a.value == "$CAPTCHA_SOLUTION"
            location = b.element(:css => a.captcha_selector).wd.location

            captcha_elem = b.element(:css => a.captcha_selector)
            width = captcha_elem.style("width").delete("px")
            height = captcha_elem.style("height").delete("px")

            screenshot_location = random_captcha_location
            b.driver.save_screenshot(screenshot_location)
            crop_screenshot_from_coords screenshot_location, location.x, location.y, width, height

            captcha_value = yield screenshot_location.sub(Padrino.root + "/public","")
            b.element(:css => a.selector).to_subtype.set(captcha_value)
          else
            b.element(:css => a.selector).to_subtype.set(f[a.value]) unless f[a.value].nil?
          end
        when "select"
          if f[a.value].nil?
            elem = b.element(:css => a.selector).to_subtype
            begin
              elem.select_value(a.value)
            rescue Watir::Exception::NoValueFoundException
              elem.select(a.value)
            end
          else
            elem = b.element(:css => a.selector).to_subtype
            begin
              elem.select_value(f[a.value])
            rescue Watir::Exception::NoValueFoundException
              elem.select(f[a.value])
            end
          end
        when "click_on"
          b.element(:css => a.selector).to_subtype.click
        when "find"
          if a.value.nil?
            b.element(:css => a.selector).wait_until_present
          else
            b.element(:css => a.selector).parent.element(:text => a.value).wait_until_present
          end
        when "check"
          b.element(:css => a.selector).to_subtype.set
        when "uncheck"
          b.element(:css => a.selector).to_subtype.clear
        when "choose"
          if a.options.nil?
            b.element(:css => a.selector).to_subtype.set
          else
            b.element(:css => a.selector + '[value="' + f[a.value].gsub('"', '\"') + '"]').to_subtype.set
          end
        end
      end

      success = check_success b.text

      success_hash = {success: success}
      success_hash[:screenshot] = self.class::save_random_screenshot_watir(b.driver) if !success and DEBUG_ENDPOINTS
      success_hash
    rescue Exception => e
      message = {message: e.message}
      message[:screenshot] = self.class::save_random_screenshot_watir(b.driver) if DEBUG_ENDPOINTS
      raise e, YAML.dump(message)
    ensure
      b.close
    end
  end

  DEFAULT_FIND_WAIT_TIME = 5  
  def fill_out_form_with_poltergeist f={}
    session = Capybara::Session.new(:poltergeist)
    session.driver.options[:js_errors] = false
    begin
      actions.order(:step).each do |a|
        case a.action
        when "visit"
          session.visit(a.value)
        when "fill_in"
          if a.value == "$CAPTCHA_SOLUTION"
            location = session.driver.evaluate_script 'document.querySelector("' + a.captcha_selector.gsub('"', '\"') + '").getBoundingClientRect();'

            screenshot_location = random_captcha_location
            session.save_screenshot(screenshot_location, full: true)
            crop_screenshot_from_coords screenshot_location, location["left"], location["top"], location["width"], location["height"]

            captcha_value = yield screenshot_location.sub(Padrino.root + "/public","")
            session.find(a.selector).set(captcha_value)
          else
            session.find(a.selector).set(f[a.value]) unless f[a.value].nil?
          end
        when "select"
          session.within a.selector do
            if f[a.value].nil?
              begin
                elem = session.find('option[value="' + a.value.gsub('"', '\"') + '"]')
              rescue Capybara::Ambiguous
                elem = session.find('option[value="' + a.value.gsub('"', '\"') + '"]:nth-child(1)')
              rescue Capybara::ElementNotFound
                elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(a.value) + "$"))
              end
              elem.select_option
            else
              begin
                elem = session.find('option[value="' + f[a.value].gsub('"', '\"') + '"]')
              rescue Capybara::Ambiguous
                elem = session.find('option[value="' + f[a.value].gsub('"', '\"') + '"]:nth-child(1)')
              rescue Capybara::ElementNotFound
                elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(f[a.value]) + "$"))
              end
              elem.select_option
            end
          end
        when "click_on"
          session.find(a.selector).click
        when "find"
          wait_val = DEFAULT_FIND_WAIT_TIME
          if a.options
            options_hash = YAML.load a.options
            wait_val = options_hash['wait'] || DEFAULT_FIND_WAIT_TIME
          end
          if a.value.nil?
            session.find(a.selector, wait: wait_val)
          else
            session.find(a.selector, text: Regexp.compile("^" + Regexp.escape(a.value) + "$"), wait: wait_val)
          end
        when "check"
          session.find(a.selector).set(true)
        when "uncheck"
          session.find(a.selector).set(false)
        when "choose"
          if a.options.nil?
            session.find(a.selector).set(true)
          else
            session.find(a.selector + '[value="' + f[a.value].gsub('"', '\"') + '"]').set(true)
          end
        end
      end

      success = check_success session.text

      success_hash = {success: success}
      success_hash[:screenshot] = self.class::save_random_screenshot_poltergeist(session) if !success and DEBUG_ENDPOINTS
      success_hash
    rescue Exception => e
      message = {message: e.message}
      message[:screenshot] = self.class::save_random_screenshot_poltergeist(session) if DEBUG_ENDPOINTS
      raise e, YAML.dump(message)
    ensure
      session.driver.quit
    end
  end

  def crop_screenshot_from_coords screenshot_location, x, y, width, height
    img = MiniMagick::Image.open(screenshot_location)
    img.crop width.to_s + 'x' + height.to_s + "+" + x.to_s + "+" + y.to_s
    img.write screenshot_location
  end

  def random_captcha_location
    Padrino.root + "/public/captchas/" + SecureRandom.hex(13) + ".png"
  end

  def self.save_random_screenshot_poltergeist session
    screenshot_location = random_screenshot_location
    session.save_screenshot(screenshot_location, full: true)
    screenshot_location.sub(Padrino.root + "/public","")
  end

  def self.save_random_screenshot_watir driver
    screenshot_location = random_screenshot_location
    driver.save_screenshot(screenshot_location)
    screenshot_location.sub(Padrino.root + "/public","")
  end

  def self.random_screenshot_location
    Padrino.root + "/public/screenshots/" + SecureRandom.hex(13) + ".png"
  end

  def has_captcha?
    !actions.find_by_value("$CAPTCHA_SOLUTION").nil?
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

  def recent_fill_status
    statuses = recent_fill_statuses
    {
      successes: statuses.success.count,
      errors: statuses.error.count,
      failures: statuses.failure.count
    }
  end

  def form_domain_url
    visit_action = actions.where(action: "visit").first
    return nil if visit_action.nil?
    url = URI.parse(visit_action.value)
    url.scheme + "://" + url.host
  end
end
