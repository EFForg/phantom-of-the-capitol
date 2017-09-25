
module CwcHelper
  def cwc_office_supported?(office_code)
    if Cwc::Client.default_client_configuration.blank?
      false
    else
      Cwc::Client.new.office_supported?(office_code)
    end
  end
end
