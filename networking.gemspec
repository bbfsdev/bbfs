require File.expand_path('../lib/networking/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'networking'
  s.version     = BBFS::Networking::VERSION
  s.summary     = 'Easy to use simple tools for networking (tcp/ip, ect,...).'
  s.description = 'Easy to use simple tools for networking (tcp/ip, ect,...).'
  s.authors     = ['Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/networking.rb', 'lib/networking/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/networking/**/*'] & `git ls-files -z`.split("\0")
  s.add_dependency('params')
end
