class FormFiller::CapybaraAction
  DEFAULT_FIND_WAIT_TIME = 5

  attr_accessor :congress_member_action

  def method_missing(method, *args)
    # delegate all methods to congress_member_action
    return congress_member_action.send(method, *args) if congress_member_action.try(:respond_to?, method)
    super
  end

  def initialize(congress_member_action, session, fields)
    @congress_member_action = congress_member_action
    @session = session
    @fields = fields
  end

  def execute(&block)
    if CongressMemberAction::ACTIONS.include?(action)
      self.send(action)
    else
      message = "No fill handler for #{action}"
      Padrino.logger.info(message)

      Raven.extra_context(fill_log: "") unless Raven.context.extra.key?(:fill_log)
      Raven.context.extra[:fill_log] << message << "\n"

      true
    end
  end

  def congress_member_action
    @congress_member_action
  end

  private

  def fill_in
    return if value.nil?
    return @session.find(selector).set(value) unless value.starts_with?("$")

    if @fields[value].present?
      max_length = options && YAML.load(options).fetch("max_length", nil)
      @fields[value] = @fields[value][0...(0.95 * max_length).floor] if max_length

      @session.find(selector).set(@fields[value].gsub("\t","    "))
    end
  end

  def visit
    @session.visit(value)
  end

  def wait
    sleep value.to_i
  end

  def javascript
    @session.driver.evaluate_script(value)
  end

  def uncheck
    @session.find(selector).set(false)
  end

  def check
    @session.find(selector).set(true)
  end

  def click_on
    @session.find(selector).click
  end

  def choose
    if options.nil?
      @session.find(selector).set(true)
    else
      @session.find(element_name(@fields[value], selector)).set(true)
    end
  end

  def find
    wait_val = DEFAULT_FIND_WAIT_TIME
    if options
      options_hash = YAML.load options
      wait_val = options_hash['wait'] || wait_val
    end
    if value.nil?
      @session.find(selector, wait: wait_val)
    else
      @session.find(selector, text: Regexp.compile(value), wait: wait_val)
    end
  end

  def select
    begin
      current_value = @fields[value] || value
      elem = begin
        return nil if @fields[value].nil? && PLACEHOLDER_VALUES.include?(value)

        begin
          @session.first(element_name(current_value))
        rescue Capybara::ElementNotFound
          @session.first('option', text: Regexp.compile("^" + Regexp.escape(current_value) + "(\\W|$)"))
        end
      end

      @session.within(selector) { elem.select_option } if elem
    rescue Capybara::ElementNotFound => e
      raise e, e.message unless options == "DEPENDENT"
    end
  end

  def element_name(value, selector = 'option')
    selector + '[value="' + value.gsub('"', '\"') + '"]'
  end
end
