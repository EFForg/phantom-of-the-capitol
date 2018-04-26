Gem::Specification.new do |s|
  s.name        = "cwc"
  s.version     = "0.0.1"
  s.date        = "2016-11-29"
  s.summary     = "CWC"
  s.description = "A client for CWC"
  s.authors     = ["Peter Woo"]
  s.email       = "peterw@eff.org"
  s.files       = `find lib -type f`.lines.map(&:chomp)

  s.add_runtime_dependency "nokogiri", ">= 1.8.2"
  s.add_runtime_dependency "rest-client"

  s.add_development_dependency "pry"
  s.add_development_dependency "rspec"
end
