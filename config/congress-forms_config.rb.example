CAPTCHA_TIMEOUT = 120
DELAY_ALL_NONCAPTCHA_FILLS = false
CORS_ALLOWED_DOMAINS = %w[http://www.example.com]
RECORD_FILL_STATUSES = true
DEBUG_KEY = "" # password needed to access sensitive info on this instance. change!

CarrierWave.configure do |config|
  config.fog_credentials = {
    provider:              'AWS',
    aws_access_key_id:     '',
    aws_secret_access_key: ''
  }
  config.fog_directory = 'congress-forms'
end
