RACK_ENV = ENV["RACK_ENV"] = 'test'
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")

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
