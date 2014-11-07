CAPTCHA_TIMEOUT = 120
DELAY_ALL_NONCAPTCHA_FILLS = false
CORS_ALLOWED_DOMAINS = %w[http://www.example.com]
RECORD_FILL_STATUSES = true
DEBUG_KEY = "" # password needed to access sensitive info on this instance. change!

# smarty streets is needed for some rake tasks - https://smartystreets.com
SMARTY_STREETS_ID = "" 
SMARTY_STREETS_TOKEN = ""

CarrierWave.configure do |config|
  config.fog_credentials = {
    provider:              'AWS',
    aws_access_key_id:     "#{ENV['AWS_ACCESS_KEY_ID']}",
    aws_secret_access_key: "#{ENV['AWS_SECRET_ACCESS_KEY_ID']}"
  }
  config.fog_directory = 'congress-forms'
end

Time.zone = "America/Los_Angeles"
