require File.expand_path('../lib/testing_server/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'testing_server'
  s.version     = FileCopy::VERSION
  s.summary     = 'Gem for running testing server for backup and content servers.'
  s.description = 'Gem for running testing server for backup and content servers.'
  s.authors     = ['Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/testing_server.rb', 'lib/testing_server/**/*'] \
                  & `git ls-files -z`.split("\0")
end
