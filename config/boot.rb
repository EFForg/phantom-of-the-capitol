# Defines our constants
PADRINO_ENV  = ENV['PADRINO_ENV'] ||= ENV['RACK_ENV'] ||= 'development'  unless defined?(PADRINO_ENV)
PADRINO_ROOT = File.expand_path('../..', __FILE__) unless defined?(PADRINO_ROOT)

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
Bundler.require(:default, PADRINO_ENV)
Padrino.require("#{Padrino.root}/config/congress-forms_config.rb")
if File.exists?(file = "#{Padrino.root}/config/constants.rb")
  require file
end

HEADLESS = Headless.new
HEADLESS.start

require 'capybara/poltergeist'
Capybara.run_server = false
Capybara.default_wait_time = 5


SmartyStreets.configure do |c|
  c.auth_id = SMARTY_STREETS_ID
  c.auth_token = SMARTY_STREETS_TOKEN
  c.number_of_candidates = 1
end

##
# ## Enable devel logging
#
Padrino::Logger::Config[:production][:log_level]  = :debug
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
  Padrino.dependency_paths << Padrino.root("app/uploaders/*.rb")
end

##
# Add your after (RE)load hooks here
#
Padrino.after_load do
  ActiveRecord::Base.default_timezone = :utc
end

Padrino.load!
