require File.expand_path('../lib/file_monitoring/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'file_monitoring'
  s.version     = BBFS::FileMonitoring::VERSION
  s.date        = '2012-01-01'
  s.summary     = 'Deamon for monitoring file changes.'
  s.description = 'Deamon for monitoring file changes in set of patterns (blobs).'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/file_monitoring.rb', 'lib/file_monitoring/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/file_monitoring/**/*', 'test/file_monitoring/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.executables << 'file_monitoring'
  s.add_dependency('algorithms')
  s.add_dependency('daemons')
  s.add_dependency('log')
  s.add_dependency('params')
end
