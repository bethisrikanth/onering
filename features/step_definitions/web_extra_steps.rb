Given /^(?:|I )am at (.+)$/ do |path|
  visit path
end

Then /^(?:|I )should see '(.*)' => '(.*)' in the JSON response$/ do |key, value|
  require 'json'
  json   = JSON.parse(page.body)
  json.get(key).should == value
end
