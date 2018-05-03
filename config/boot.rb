# Defines our constants
RACK_ENV = ENV['RACK_ENV'] ||= 'development'  unless defined?(RACK_ENV)
PADRINO_ROOT = File.expand_path('../..', __FILE__) unless defined?(PADRINO_ROOT)

$LOAD_PATH << File.expand_path("#{PADRINO_ROOT}/cwc/lib")
require "cwc" if RACK_ENV == "production"

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
Bundler.require(:default, RACK_ENV)

require "cwc"

require "dotenv/load"
require "#{Padrino.root}/config/env.rb"
require "#{Padrino.root}/config/phantom-dc_config.rb"

if File.exists?(file = "#{Padrino.root}/config/constants.rb")
  require file
end

require 'capybara/poltergeist'
Capybara.run_server = false
Capybara.default_max_wait_time = 5

Capybara.register_driver :poltergeist do |app|
  options = {
    js_errors: false,
    phantomjs_options: ['--ssl-protocol=TLSv1'],
    url_blacklist: ENV.fetch('URL_BLACKLIST'){ '' }.split(',')
  }

  Capybara::Poltergeist::Driver.new(app, options)
end


SmartyStreets.configure do |c|
  c.auth_id = SMARTY_STREETS_ID
  c.auth_token = SMARTY_STREETS_TOKEN
  c.candidates = 1
end

unless SENTRY_DSN.nil?
  Raven.configure do |config|
    config.dsn = SENTRY_DSN
  end

  Padrino.use Raven::Rack
end

##
# ## Enable devel logging
#
# Padrino::Logger::Config[:development][:log_level]  = :devel
# Padrino::Logger::Config[:development][:log_static] = true
#
# ## Configure your I18n
#
# I18n.default_locale = :en
#
# ## Configure your HTML5 data helpers
#
# Padrino::Helpers::TagHelpers::DATA_ATTRIBUTES.push(:dialog)
# text_field :foo, :dialog => true
# Generates: <input type="text" data-dialog="true" name="foo" />
#
# ## Add helpers to mailer
#
# Mail::Message.class_eval do
#   include Padrino::Helpers::NumberHelpers
#   include Padrino::Helpers::TranslationHelpers
# end

##
# Add your before (RE)load hooks here
#
Padrino.before_load do
  Padrino.dependency_paths.unshift Padrino.root("app/concerns/*.rb")
  Padrino.dependency_paths << Padrino.root("app/uploaders/*.rb")
  Padrino.dependency_paths << Padrino.root("app/tasks/*.rb")
  Padrino.dependency_paths << Padrino.root("app/helpers/*.rb")
end

##
# Add your after (RE)load hooks here
#
Padrino.after_load do
  ActiveRecord::Base.default_timezone = :utc
  Time.zone = TIME_ZONE
end

Padrino.load!
