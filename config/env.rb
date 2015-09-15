class String
  def to_bool
    return true if self == true || self =~ (/^(true|t|yes|y|1)$/i)
    return false if self == false || self.blank? || self =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

ENV_PRIME = ENV.to_hash.merge({
  'CAPTCHA_TIMEOUT' => ENV['CAPTCHA_TIMEOUT'].nil? ? nil : ENV['CAPTCHA_TIMEOUT'].to_i,
  'DELAY_ALL_NONCAPTCHA_FILLS' => ENV['DELAY_ALL_NONCAPTCHA_FILLS'].nil? ? nil : ENV['DELAY_ALL_NONCAPTCHA_FILLS'].to_bool,
  'CORS_ALLOWED_DOMAINS' => ENV['CORS_ALLOWED_DOMAINS'].nil? ? nil : ENV['CORS_ALLOWED_DOMAINS'].split(" "),
  'RECORD_FILL_STATUSES' => ENV['RECORD_FILL_STATUSES'].nil? ? nil : ENV['RECORD_FILL_STATUSES'].split(" ")
})
