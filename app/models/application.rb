class Application < ActiveRecord::Base
  self.table_name = "application_settings"
  
  def self.method_missing(method, *args, &block)
    return self.send method, *args, &block if self.respond_to? method
    method_name = method.to_s
    if method_name =~ /=/
      return self.set method_name.gsub("=", ""), args.first
    else
      return self.get method_name
    end
  end
  
  private 
  def self.get setting
    entry = Application.where(:key => setting).first
    entry.nil? ? nil : YAML.load(entry.value)
  end
  
  def self.set key, value
    setting = Application.where(:key => key).first || Application.new(:key => key)
    setting.update_attribute(:value, value.to_yaml)
  end
end

