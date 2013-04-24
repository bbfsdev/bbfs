require File.expand_path('../lib/log/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'log'
  s.version     = Log::VERSION
  s.summary     = 'Library for logging data.'
  s.description = 'logging data to file, console etc. Data can be pushed using info\warning\error\debug-levels categories'
  s.authors     = ['Yaron Dror']
  s.email       = 'yaron.dror.bb@gmail.com'
  s.homepage    = 'http://github.com/yarondbb/bbfs'
  s.files       = Dir['lib/log.rb', 'lib/log/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/log/**/*', 'test/log/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.add_dependency('params')
  s.add_dependency('log4r')
  #s.add_dependency('log4r/outputter/emailoutputter')
end
