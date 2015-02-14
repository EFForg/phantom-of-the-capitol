class LegacySerializer
  def self.load(value)
    value
  end

  def self.dump(value)
    return value if value.is_a? String or value.nil?
    YAML.dump(value)
  end
end
