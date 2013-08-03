require File.expand_path('../lib/email/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'email'
  s.version     = SendEmail::VERSION
  s.summary     = 'Library for sending emails via gmail smtp.'
  s.description = 'Library for sending emails via gmail smtp.'
  s.authors     = ['Kolman Vornovitsky']
  s.email       = 'bbfsdev@gmail.com'
  s.homepage    = 'http://github.com/bbfsdev/bbfs'
  s.files       = Dir['lib/email.rb', 'lib/email/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.add_dependency('log')
  s.add_dependency('params')
end
