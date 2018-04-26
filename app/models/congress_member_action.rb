class CongressMemberAction < ActiveRecord::Base
  validates_presence_of :action

  REQUIRED_JSON = {
    :only => [
      :value,
      :maxlength
    ],
    :methods => [:options_hash]
  }

  DEFAULT_FIND_WAIT_TIME = 5

  belongs_to :congress_member

  serialize :options, LegacySerializer

  extend Enumerize
  enumerize :action, in: %w(visit fill_in select click_on find check uncheck choose wait javascript recaptcha)

  def as_required_json o={}
    as_json(REQUIRED_JSON.merge o)
  end

  def options_hash
    return nil if options.nil?
    return CONSTANTS[options]["value"] if defined? CONSTANTS and CONSTANTS.include? options
    YAML.load(options)
  end

  def execute(session, cm, f)
    bioguide_id = cm.bioguide_id

    case action
    when "visit"
      session.visit(value)
    when "wait"
      sleep value.to_i
    when "fill_in"
      if value.starts_with?("$")
        if value == "$CAPTCHA_SOLUTION"
          location = CAPTCHA_LOCATIONS.keys.include?(bioguide_id) ? CAPTCHA_LOCATIONS[bioguide_id] : session.driver.evaluate_script('document.querySelector("' + captcha_selector.gsub('"', '\"') + '").getBoundingClientRect();')
          url = cm.class.save_captcha_and_store_poltergeist session, location["left"], location["top"], location["width"], location["height"]

          yield(url, session, self) unless f["$CAPTCHA_SOLUTION"]
          session.find(selector).set(f["$CAPTCHA_SOLUTION"])
        else
          if options
            opts = YAML.load options
            if opts.include? "max_length"
              f[value] = f[value][0...(0.95 * opts["max_length"]).floor] unless f[value].nil?
            end
          end
          session.find(selector).set(f[value].gsub("\t","    ")) unless f[value].nil?
        end
      else
        session.find(selector).set(value) unless value.nil?
      end
    when "select"
      begin
        session.within selector do
          if f[value].nil?
            unless PLACEHOLDER_VALUES.include? value
              begin
                elem = session.find('option[value="' + value.gsub('"', '\"') + '"]')
              rescue Capybara::Ambiguous
                elem = session.first('option[value="' + value.gsub('"', '\"') + '"]')
              rescue Capybara::ElementNotFound
                begin
                  elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(value) + "(\\W|$)"))
                rescue Capybara::Ambiguous
                  elem = session.first('option', text: Regexp.compile("^" + Regexp.escape(value) + "(\\W|$)"))
                end
              end
              elem.select_option
            end
          else
            begin
              elem = session.find('option[value="' + f[value].gsub('"', '\"') + '"]')
            rescue Capybara::Ambiguous
              elem = session.first('option[value="' + f[value].gsub('"', '\"') + '"]')
            rescue Capybara::ElementNotFound
              begin
                elem = session.find('option', text: Regexp.compile("^" + Regexp.escape(f[value]) + "(\\W|$)"))
              rescue Capybara::Ambiguous
                elem = session.first('option', text: Regexp.compile("^" + Regexp.escape(f[value]) + "(\\W|$)"))
              end
            end
            elem.select_option
          end
        end
      rescue Capybara::ElementNotFound => e
        raise e, e.message unless options == "DEPENDENT"
      end
    when "click_on"
      session.find(selector).click
    when "find"
      wait_val = DEFAULT_FIND_WAIT_TIME
      if options
        options_hash = YAML.load options
        wait_val = options_hash['wait'] || DEFAULT_FIND_WAIT_TIME
      end
      if value.nil?
        session.find(selector, wait: wait_val)
      else
        session.find(selector, text: Regexp.compile(value), wait: wait_val)
      end
    when "check"
      session.find(selector).set(true)
    when "uncheck"
      session.find(selector).set(false)
    when "choose"
      if options.nil?
        session.find(selector).set(true)
      else
        session.find(selector + '[value="' + f[value].gsub('"', '\"') + '"]').set(true)
      end
    when "javascript"
      session.driver.evaluate_script(value)
    end
  end
end
