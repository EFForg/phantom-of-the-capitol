class CongressMemberAction < ActiveRecord::Base
  extend Enumerize

  REQUIRED_JSON = { :only => [ :value, :maxlength ], :methods => [:options_hash] }
  DEFAULT_FIND_WAIT_TIME = 5

  validates_presence_of :action

  belongs_to :congress_member

  serialize :options, LegacySerializer
  enumerize :action, in: %w(visit fill_in select click_on find check uncheck choose wait javascript recaptcha)

  def execute(session, f)
    self.send(action, session, f)
  end

  private

  def fill_in(session, f)
    return if value.nil?
    return session.find(selector).set(value) unless value.starts_with?("$")

    if f[value].present?
      max_length = options && YAML.load(options).fetch("max_length", nil)
      f[value] = f[value][0...(0.95 * max_length).floor] if max_length

      session.find(selector).set(f[value].gsub("\t","    "))
    end
  end

  def visit(session, _f)
    session.visit(value)
  end

  def wait(_session, _f)
    sleep value.to_i
  end

  def javascript(session, _f)
    session.driver.evaluate_script(value)
  end

  def uncheck(session, _f)
    session.find(selector).set(false)
  end

  def check(session, _f)
    session.find(selector).set(true)
  end

  def click_on(session, _f)
    session.find(selector).click
  end

  def choose(session, f)
    if options.nil?
      session.find(selector).set(true)
    else
      session.find(element_name(f[value], selector)).set(true)
    end
  end

  def find(session, _f)
    wait_val = DEFAULT_FIND_WAIT_TIME
    if options
      options_hash = YAML.load options
      wait_val = options_hash['wait'] || wait_val
    end
    if value.nil?
      session.find(selector, wait: wait_val)
    else
      session.find(selector, text: Regexp.compile(value), wait: wait_val)
    end
  end

  def select(session, f)
    begin
      current_value = f[value] || value
      elem = begin
        return nil if f[value].nil? && PLACEHOLDER_VALUES.include?(value)

        begin
          session.first(element_name(current_value))
        rescue Capybara::ElementNotFound
          session.first('option', text: Regexp.compile("^" + Regexp.escape(current_value) + "(\\W|$)"))
        end
      end

      session.within(selector) { elem.select_option } if elem
    rescue Capybara::ElementNotFound => e
      raise e, e.message unless options == "DEPENDENT"
    end
  end

  def element_name(value, selector = 'option')
    selector + '[value="' + value.gsub('"', '\"') + '"]'
  end
end
