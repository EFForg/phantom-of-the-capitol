PADRINO_ENV = 'test' unless defined?(PADRINO_ENV)
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each { |f| require f }

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.include FactoryGirl::Syntax::Methods

  conf.before(:each) { DatabaseCleaner.clean_with :truncation }

  conf.before(:suite) do
    LocalhostServer.new(TESTSERVER.new, 3001)
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

FactoryGirl.definition_file_paths = [
  File.join(Padrino.root, 'factories'),
  File.join(Padrino.root, 'test', 'factories'),
  File.join(Padrino.root, 'spec', 'factories')
]
FactoryGirl.find_definitions
