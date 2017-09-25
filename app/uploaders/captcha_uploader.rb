class CaptchaUploader < CarrierWave::Uploader::Base
  storage :fog
  def store_dir
    Padrino.env.to_s + '/captchas'
  end
end
