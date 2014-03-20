class CongressMember < ActiveRecord::Base
  validates_presence_of :bioguide_id

  has_many :actions, :class_name => 'CongressMemberAction', :dependent => :destroy
  has_many :required_actions, :class_name => 'CongressMemberAction', :conditions => "required = 1 AND SUBSTRING(value, 1, 1) = '$'"
  has_many :fill_statuses, :class_name => 'FillStatus', :dependent => :destroy
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
    status_fields = {congress_member: self, status: "success"}.merge(ct.nil? ? {} : {campaign_tag: ct})
    begin
      begin
        success = fill_out_form_with_poltergeist f, &block
      rescue Exception => e
        status_fields[:status] = "error"
        raise e
      end

      unless success
        status_fields[:status] = "failure"
        raise FillFailure, "Filling out the remote form was not successful" 
      end
    ensure
      FillStatus.new(status_fields).save if RECORD_FILL_STATUSES
    end
    true
  end

  def fill_out_form_with_watir f={}
    b = Watir::Browser.new
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
        b.element(:css => a.selector).to_subtype.select_value(f[a.value]) unless f[a.value].nil?
      when "click_on"
        b.element(:css => a.selector).to_subtype.click
      when "find"
        b.element(:css => a.selector).wait_until_present
      when "check"
        b.element(:css => a.selector).to_subtype.set
      when "uncheck"
        b.element(:css => a.selector).to_subtype.clear
      when "choose"
        b.element(:css => a.selector).to_subtype.set
      end
    end
    success = check_success b.text
    b.close
    success
  end

  def fill_out_form_with_poltergeist f={}
    session = Capybara::Session.new(:poltergeist)
    session.driver.options[:js_errors] = false
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
          session.find('option[value="' + f[a.value].gsub('"', '\"') + '"]').select_option unless f[a.value].nil?
        end
      when "click_on"
        session.find(a.selector).click
      when "find"
        session.find(a.selector)
      when "check"
        session.find(a.selector).set(true)
      when "uncheck"
        session.find(a.selector).set(false)
      when "choose"
        session.find(a.selector).set(true)
      end
    end

    success = check_success session.text
    session.driver.quit
    success
  end

  def crop_screenshot_from_coords screenshot_location, x, y, width, height
    img = MiniMagick::Image.open(screenshot_location)
    img.crop width.to_s + 'x' + height.to_s + "+" + x.to_s + "+" + y.to_s
    img.write screenshot_location
  end

  def random_captcha_location
    Padrino.root + "/public/captchas/" + SecureRandom.hex(13) + ".png"
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
    statuses = fill_statuses.where('created_at > ?', updated_at)
    {
      successes: statuses.success.count,
      errors: statuses.error.count,
      failures: statuses.failure.count
    }
  end
end
