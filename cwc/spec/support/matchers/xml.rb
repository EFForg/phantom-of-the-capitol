
require "rspec/expectations"

RSpec::Matchers.define :have_xpath do |xpath, content|
  match do |doc|
    if content
      !doc.at_xpath(xpath).nil? && doc.at_xpath(xpath).content == content
    else
      !doc.at_xpath(xpath).nil?
    end
  end

  failure_message do |actual|
    actual = actual.inspect
    actual = actual.size > 35 ? "#{actual[0, 35]}..." : actual

    if content
      %(expected #{actual} to have xpath "#{xpath}" with content "#{content}")
    else
      %(expected #{actual} to have xpath "#{xpath}")
    end
  end

  failure_message_when_negated do |actual|
    actual = actual.inspect
    actual = actual.size > 35 ? "#{actual[0, 35]}..." : actual

    if content
      %(expected #{actual} not to have xpath "#{xpath}" with content "#{content}")
    else
      %(expected #{actual} not to have xpath "#{xpath}")
    end
  end
end

