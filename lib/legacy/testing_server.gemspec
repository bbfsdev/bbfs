require File.expand_path('../lib/testing_server/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'testing_server'
  s.version     = TestingServer::VERSION
  s.summary     = 'Testing Server for backup system validation'
  s.description = 'The server runs 24-7, generates/deletes files and validates content at backup periodically.'
  s.authors     = ['BBFS Team']
  s.email       = 'bbfsdev@gmail.com'
  s.homepage    = 'http://github.com/bbfsdev/bbfs'
  s.files       = Dir['lib/testing_server.rb', 'lib/testing_server/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/testing_server/**/*'] & `git ls-files -z`.split("\0")
  s.executables = ['testing_server']
  s.add_runtime_dependency('content_server', '>=1.1.0')
  s.add_dependency('content_server', '>=1.1.0')
end
