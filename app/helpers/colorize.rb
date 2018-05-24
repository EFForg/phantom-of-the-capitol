def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def red(text)
  colorize(text, 31)
end

def success_color(success_rate)
  darkness = 0.8
  red = (1 - ([success_rate - 0.5, 0].max * 2)) * 255 * darkness
  green = [success_rate * 2, 1].min * 255 * darkness
  blue = 0
  sprintf("%02X%02X%02X", red, green, blue)
end
