require File.expand_path('../lib/params/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'params'
  s.version     = Params::VERSION
  s.summary     = 'Dynamically stores, parses and providers params.'
  s.description = 'Dynamically stores, parses and providers params. Uses module local readers.'
  s.authors     = ['Gena Petelko', 'Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/params.rb', 'lib/params/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/params/**/*', 'test/params/**/*'] \
                  & `git ls-files -z`.split("\0")
end
