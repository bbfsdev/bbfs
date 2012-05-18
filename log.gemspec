require File.expand_path('../lib/log/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'log'
  s.version     = BBFS::Log::VERSION
  s.summary     = 'Library for logging data.'
  s.description = 'logging data to file, console etc. Data can be pushed using info\warning\error\debug-levels categories'
  s.authors     = ['Yaron Dror']
  s.email       = 'yaron.dror.bb@gmail.com'
  s.homepage    = 'http://github.com/yarondbb/bbfs'
  s.files       = ['lib/log.rb',
                   'lib/log/log_consumer.rb']
  s.test_files  = ['test/log/log_test.rb']
  s.add_dependency('params')
end
