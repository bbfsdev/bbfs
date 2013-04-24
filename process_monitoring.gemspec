require File.expand_path('../lib/process_monitoring/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'process_monitoring'
  s.version     = ProcessMonitoring::VERSION
  s.summary     = 'Library to add monitoring for processes.'
  s.description = 'Holds variable set which is regularly updated and export it to http protocol'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'bbfsdev@gmail.com'
  s.homepage    = 'http://github.com/bbfsdev/bbfs'
  s.files       = Dir[ 'lib/process_monitoring.rb', 'lib/process_monitoring/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['examples/process_monitoring.rb', 'spec/process_monitoring/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.add_dependency('thin')
  s.add_dependency('eventmachine')
  s.add_dependency('log')
  s.add_dependency('params')
  s.add_dependency('json')
  #s.add_dependency('net-http')
end
