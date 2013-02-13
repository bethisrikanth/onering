Before do
  @string = {}
end


Given /^I want the boolean value of '(.*)'$/ do |value|
  @string = value.to_bool
end

Then /^I should see a true value$/ do
  @string.should === true
end

Then /^I should see a false value$/ do
  @string.should === false
end