class ScreenshotUploader < CarrierWave::Uploader::Base
  storage :fog
  def store_dir
    Padrino.env.to_s + '/screenshots'
  end
end
