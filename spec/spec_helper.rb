RACK_ENV = ENV["RACK_ENV"] = 'test'
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each { |f| require f }

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.include FactoryGirl::Syntax::Methods

  conf.before(:each) do
    DatabaseCleaner.clean_with :truncation
    allow_any_instance_of(CaptchaUploader).to receive(:'store!')
    allow_any_instance_of(ScreenshotUploader).to receive(:'store!')
  end

  conf.before(:suite) do
    LocalhostServer.new(TESTSERVER.new, 3002)
  end

end

# You can use this method to custom specify a Rack app
# you want rack-test to invoke:
#
#   app Myapp::App
#   app Myapp::App.tap { |a| }
#   app(Myapp::App) do
#     set :foo, :bar
#   end
#
def app(app = nil, &blk)
  @app ||= block_given? ? app.instance_eval(&blk) : app
  @app ||= Padrino.application
end

def post_json route, json
  post route, json, {'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
end

def put_json route, json
  put route, json, {'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
end

FactoryGirl.definition_file_paths = [
  File.join(Padrino.root, 'factories'),
  File.join(Padrino.root, 'test', 'factories'),
  File.join(Padrino.root, 'spec', 'factories')
]
FactoryGirl.find_definitions

MOCK_VALUES = {
  "$NAME_FIRST" => "John",
  "$NAME_LAST" => "Doe",
  "$ADDRESS_STREET" => "123 Main Street",
  "$ADDRESS_CITY" => "New York",
  "$ADDRESS_ZIP5" => "10112",
  "$ADDRESS_STATE_POSTAL_ABBREV" => "NY",
  "$EMAIL" => "joe@example.com",
  "$TOPIC" => "Education",
  "$SUBJECT" => "Recent legislation",
  "$MESSAGE" => "I have concerns about the proposal....",
  "$NAME_PREFIX" => "4"
}
