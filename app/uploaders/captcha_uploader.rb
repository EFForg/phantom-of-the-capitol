class CaptchaUploader < CarrierWave::Uploader::Base
  storage :fog
  def store_dir
    'captchas'
  end
end
