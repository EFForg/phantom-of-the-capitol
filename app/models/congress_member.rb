class CongressMember < ActiveRecord::Base
  validates_presence_of :bioguide_id

  has_many :actions, :class_name => 'CongressMemberAction', :dependent => :destroy
  has_many :required_actions, -> (object) { where "required = true AND SUBSTRING(value, 1, 1) = '$'" }, :class_name => 'CongressMemberAction'
  has_many :fill_statuses, :class_name => 'FillStatus', :dependent => :destroy
  has_many :recent_fill_statuses, -> (object) { where("created_at > ?", object.updated_at) }, :class_name => 'FillStatus'
  #has_one :captcha_action, :class_name => 'CongressMemberAction', :condition => "value = '$CAPTCHA_SOLUTION'"

  serialize :success_criteria, LegacySerializer

  RECENT_FILL_IMAGE_BASE = 'https://img.shields.io/badge/'
  RECENT_FILL_IMAGE_EXT = '.svg'
  
  @@bioguide_id_ref = ''

  class FillFailure < StandardError
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
    yield self.find_or_create_by bioguide_id: bioguide_id
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
        @@bioguide_id_ref = self.bioguide_id

        if REQUIRES_WATIR.include? self.bioguide_id
          success_hash = fill_out_form_with_watir f, &block
        elsif REQUIRES_WEBKIT.include? self.bioguide_id
          success_hash = fill_out_form_with_webkit f, &block
        else
          success_hash = fill_out_form_with_poltergeist f, &block
        end
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
      unless ENV['SKIP_DELAY']
        self.delay(queue: "error_or_failure").fill_out_form f, ct
        last_job = Delayed::Job.last
        last_job.attempts = 1
        last_job.run_at = Time.now
        last_job.last_error = e.message + "\n" + e.backtrace.inspect
        last_job.save
        status_fields[:extra][:delayed_job_id] = last_job.id
      end
      raise e
    ensure
      FillStatus.new(status_fields).save if RECORD_FILL_STATUSES
    end
    true
  end

  # we might want to implement the "wait" option for the "find"
  # directive (see fill_out_form_with_poltergeist)
  def fill_out_form_with_watir f={}
    b = Watir::Browser.new
    begin
      actions.order(:step).each do |a|
        case a.action
        when "visit"
          b.goto a.value
        when "wait"
          sleep a.value.to_i
        when "fill_in"
          if a.value.starts_with?("$")
            if a.value == "$CAPTCHA_SOLUTION"
              location = b.element(:css => a.captcha_selector).wd.location

              captcha_elem = b.element(:css => a.captcha_selector)
              width = captcha_elem.style("width").delete("px")
              height = captcha_elem.style("height").delete("px")

              url = self.class::save_captcha_and_store_watir b.driver, location.x, location.y, width, height

              captcha_value = yield url
              b.element(:css => a.selector).to_subtype.set(captcha_value)
            else
              if a.options
                options = YAML.load a.options
                if options.include? "max_length"
                  f[a.value] = f[a.value][0...(0.95 * options["max_length"]).floor]
                end
              end
              b.element(:css => a.selector).to_subtype.set(f[a.value].gsub("\t","    ")) unless f[a.value].nil?
            end
          else
            b.element(:css => a.selector).to_subtype.set(a.value) unless a.value.nil?
          end
        when "select"
          begin
            if f[a.value].nil?
              unless PLACEHOLDER_VALUES.include? a.value
                elem = b.element(:css => a.selector).to_subtype
                begin
                  elem.select_value(a.value)
                rescue Watir::Exception::NoValueFoundException
                  elem.select(a.value)
                end
              end
            else
              elem = b.element(:css => a.selector).to_subtype
              begin
                elem.select_value(f[a.value])
              rescue Watir::Exception::NoValueFoundException
                elem.select(f[a.value])
              end
            end
          rescue Watir::Exception::NoValueFoundException => e
            raise e, e.message unless a.options == "DEPENDENT"
          end
        when "click_on"
          b.element(:css => a.selector).to_subtype.click
        when "find"
          if a.value.nil?
            b.element(:css => a.selector).wait_until_present
          else
            b.element(:css => a.selector).wait_until_present
            b.element(:css => a.selector).parent.wait_until_present
            b.element(:css => a.selector).parent.element(:text => Regexp.compile(a.value)).wait_until_present
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
      success_hash[:screenshot] = self.class::save_screenshot_and_store_watir(b.driver) if !success
      success_hash
    rescue Exception => e
      message = {message: e.message}
      message[:screenshot] = self.class::save_screenshot_and_store_watir(b.driver)
      raise e, YAML.dump(message)
    ensure
      b.close
    end
  end

  DEFAULT_FIND_WAIT_TIME = 5  

  def fill_out_form_with_poltergeist f={}, &block
    fill_out_form_with_capybara f, :poltergeist, &block
  end

  def fill_out_form_with_webkit f={}, &block
    fill_out_form_with_capybara f, :webkit, &block
  end

  def fill_out_form_with_capybara f={}, driver
    session = Capybara::Session.new(driver)
    session.driver.options[:js_errors] = false if driver == :poltergeist
    session.driver.options[:phantomjs_options] = ['--ssl-protocol=TLSv1'] if driver == :poltergeist
    begin
      actions.order(:step).each do |a|
#        puts a.name
        case a.action
        when "visit"
          session.visit(a.value)
        when "wait"
          sleep a.value.to_i
        when "fill_in"
          if a.value.starts_with?("$")
            if a.value == "$CAPTCHA_SOLUTION"
              location = CAPTCHA_LOCATIONS.keys.include?(bioguide_id) ? CAPTCHA_LOCATIONS[bioguide_id] : session.driver.evaluate_script('document.querySelector("' + a.captcha_selector.gsub('"', '\"') + '").getBoundingClientRect();')

              url = self.class::save_captcha_and_store_poltergeist session, location["left"], location["top"], location["width"], location["height"]

              captcha_value = yield url
              session.find(a.selector).set(captcha_value)
            else
              if a.options
                options = YAML.load a.options
                if options.include? "max_length"
                  f[a.value] = f[a.value][0...(0.95 * options["max_length"]).floor]
                end
              end
              session.find(a.selector).set(f[a.value].gsub("\t","    ")) unless f[a.value].nil?
            end
          else
            session.find(a.selector).set(a.value) unless a.value.nil?
          end
        when "select"
          begin
            session.within a.selector do
              options = YAML.load a.options
              
              
#              puts YAML.dump options
#              if options.is_a?(Hash)
#
#               # puts options.keys
#
#                keykey=(f[a.value].gsub('? "','')).gsub('"','')
#                puts keykey
#                puts options['\n\t\t\t\t\t\t\t\t\t\t\tEconomy\n\t\t\t\t\t\t\t\t\t\t']
#              end
#
#              puts options.count

              if f[a.value].nil?
                #puts 3
                unless PLACEHOLDER_VALUES.include? a.value
                  begin
                    elem = session.find('option[value="' + a.value.gsub('"', '\"') + '"]')
                  rescue Capybara::Ambiguous
                    elem = session.first('option[value="' + a.value.gsub('"', '\"') + '"]')
                  rescue Capybara::ElementNotFound
                    begin
                      elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(a.value) + "$"))
                    rescue Capybara::Ambiguous
                      elem = session.first('option', text: Regexp.compile("^" + Regexp.escape(a.value) + "$"))
                    end
                  end
                  elem.select_option
                end
              elsif options.include?f[a.value] or options[f[a.value]].nil?
                #puts "use as the value"
                begin
                  elem = session.find('option[value="' + f[a.value].gsub('"', '\"') + '"]')
                rescue Capybara::Ambiguous
                  elem = session.first('option[value="' + f[a.value].gsub('"', '\"') + '"]')
                rescue Capybara::ElementNotFound
                  begin
                    elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(f[a.value]) + "$"))
                  rescue Capybara::Ambiguous
                    elem = session.first('option', text: Regexp.compile("^" + Regexp.escape(f[a.value]) + "$"))
                  end
                end
                elem.select_option
              else
                #puts "converted to key"
                begin
                  elem = session.find('option[value="' + options[f[a.value]].gsub('"', '\"') + '"]')
                rescue Capybara::Ambiguous
                  elem = session.first('option[value="' + options[f[a.value]].gsub('"', '\"') + '"]')
                rescue Capybara::ElementNotFound
                  begin
                    elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(options[f[a.value]]) + "$"))
                  rescue Capybara::Ambiguous
                    elem = session.first('option', text: Regexp.compile("^" + Regexp.escape(options[f[a.value]]) + "$"))
                  end
                end
                elem.select_option
              end
            end
          rescue Capybara::ElementNotFound => e
            #raise e, e.message unless (a.options == "DEPENDENT" or a.required == 0 or a.required == 1)
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
            session.find(a.selector, text: Regexp.compile(a.value), wait: wait_val)
          end
        when "question" #find the question and match it to a hash key
          pairs_hash = YAML.load a.pairs
          q=session.find(a.question_selector).text
          answer=pairs_hash[q]
          session.find(a.answer_selector).set(answer) unless answer.nil?
        when "math" 
          q=session.find(a.question_selector).text #find the question
          
          if q[0].starts_with?("*") #replace the preceding "*" from the string
            q=q[1..q.length-1]
          end

          if a.selector.to_s.length > 0 #if the question has a bunch of text, it's in the selector
            q.sub! a.selector,""
          end

          q.sub! ":","" #remove the trailing ":"
          q.strip!      #strip white space and it's assumed to be "number operator number"

          parts = q.split(" ")
          numbers = { "Zero" => 0, "One" => 1, "Two" => 2, "Three" => 3, "Four" => 4, "Five" => 5, "Six" => 6, "Seven" => 7, "Eight" => 8, "Nine" => 9 }

          if parts[0].to_i == 0 && parts[0].to_s.length>1 #is the first number a string? Match it to the numbers hash above
            parts[0]=numbers[parts[0]]
          end

          if parts[2].to_i == 0 && parts[2].to_s.length>1 #is the second number a string? Match it to the numbers hash above
            parts[2]=numbers[parts[2]]
          end

          case parts[1]
            when "+"
              answer=parts[0].to_i+parts[2].to_i
            when "-"
              answer=parts[0].to_i-parts[2].to_i
            when "*", "x", "X", "×"
              answer=parts[0].to_i*parts[2].to_i
            when "/", "÷"
              answer=parts[0].to_i/parts[2].to_i
          end

          session.find(a.answer_selector).set(answer) unless answer.nil?
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
      success_hash[:screenshot] = self.class::save_screenshot_and_store_poltergeist(session) if !success
      success_hash
    rescue Exception => e
      message = {message: e.message}
      message[:screenshot] = self.class::save_screenshot_and_store_poltergeist(session)
      raise e, YAML.dump(message)
    ensure
      case driver
      when :poltergeist
        session.driver.quit
      when :webkit
        # ugly, but it works
        pid = session.driver.browser.instance_variable_get("@connection").instance_variable_get("@pid")
        stdin = session.driver.browser.instance_variable_get("@connection").instance_variable_get("@pipe_stdin")
        stdout = session.driver.browser.instance_variable_get("@connection").instance_variable_get("@pipe_stdout")
        stderr = session.driver.browser.instance_variable_get("@connection").instance_variable_get("@pipe_stderr")
        socket = session.driver.browser.instance_variable_get("@connection").instance_variable_get("@socket")

        stdin.close
        stdout.close
        stderr.close
        socket.close
        Process.kill(3, pid)
      end
    end
  end

  def self.crop_screenshot_from_coords screenshot_location, x, y, width, height
    img = MiniMagick::Image.open(screenshot_location)
    img.crop width.to_s + 'x' + height.to_s + "+" + x.to_s + "+" + y.to_s
    img.write screenshot_location
  end

  def self.store_captcha_from_location location
    c = CaptchaUploader.new
    c.store!(File.open(location))
    c.url
  end

  def self.store_screenshot_from_location location
    s = ScreenshotUploader.new
    s.store!(File.open(location))
    s.url
  end

  def self.save_screenshot_and_store_watir driver
    screenshot_location = random_screenshot_location
    driver.save_screenshot(screenshot_location)
    url = store_screenshot_from_location screenshot_location
    File.unlink screenshot_location
    url
  end

  def self.save_screenshot_and_store_poltergeist session
    screenshot_location = random_screenshot_location
    session.save_screenshot(screenshot_location, full: true)
    url = store_screenshot_from_location screenshot_location
    File.unlink screenshot_location
    url
  end

  def self.save_captcha_and_store_watir driver, x, y, width, height 
    screenshot_location = random_captcha_location
    driver.save_screenshot(screenshot_location)
    crop_screenshot_from_coords screenshot_location, x, y, width, height
    url = store_captcha_from_location screenshot_location
    File.unlink screenshot_location
    url
  end

  def self.save_captcha_and_store_poltergeist session, x, y, width, height
    screenshot_location = random_captcha_location
    session.save_screenshot(screenshot_location, full: true)
    crop_screenshot_from_coords screenshot_location, x, y, width, height
    url = store_captcha_from_location screenshot_location
    File.unlink screenshot_location
    url
  end

  def self.random_captcha_location
    Padrino.root + "/public/captchas/" + SecureRandom.hex(13) + ".png"
  end

  def self.random_screenshot_location
    Padrino.root + "/public/screenshots/" + Time.now.strftime('%Y%m%d%H%M%S%L') + "_" + @@bioguide_id_ref + "-" + SecureRandom.hex(4) + ".png"
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

  def self.to_hash cm_array
    cm_hash = {}
    cm_array.each do |cm|
      cm_hash[cm.id.to_s] = cm
    end
    cm_hash
  end

  def self.retrieve_cached cm_hash, cm_id
    return cm_hash[cm_id] if cm_hash.include? cm_id
    cm_hash[cm_id] = self.find(cm_id)
  end

  def self.list_with_job_count cm_array
    members_ordered = cm_array.order(:bioguide_id)
    cms = members_ordered.as_json(only: :bioguide_id)

    jobs = Delayed::Job.where(queue: "error_or_failure")

    cm_hash = self.to_hash members_ordered
    people = DelayedJobHelper::tabulate_jobs_by_member jobs, cm_hash

    people.each do |bioguide, jobs_count|
      cms.select{ |cm| cm["bioguide_id"] == bioguide }.each do |cm|
        cm["jobs"] = jobs_count
      end
    end
    cms.to_json
  end

end
