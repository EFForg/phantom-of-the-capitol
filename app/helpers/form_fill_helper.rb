module FormFillHelper
  def save_screenshot
    screenshot_location = random_screenshot_location
    @session.save_screenshot(screenshot_location, full: true)
    url = store_screenshot_from_location screenshot_location
    Raven.extra_context(screenshot: url)
    File.unlink screenshot_location
    url
  end

  def save_captcha x, y, width, height
    screenshot_location = random_captcha_location
    @session.save_screenshot(screenshot_location, full: true)
    crop_screenshot_from_coords screenshot_location, x, y, width, height
    url = store_captcha_from_location screenshot_location
    File.unlink screenshot_location
    url
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
