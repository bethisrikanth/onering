source 'https://rubygems.org'

gem "snmp"
gem "net-ping"
gem "addressable"
gem "ipaddress"

gem "net-ldap"
gem "babel_bridge"
gem "eventmachine"
gem "msgpack"
gem "cucumber"
gem "git"

Dir[File.join(File.dirname(__FILE__), 'plugins', '*', 'Gemfile')].each do |gemfile|
  eval(IO.read(gemfile), binding)
end
