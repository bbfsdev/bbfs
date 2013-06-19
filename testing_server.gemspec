require File.expand_path('../lib/testing_server/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'testing_server'
  s.version     = TestingServer::VERSION
  s.summary     = 'Testing Server for backup system validation'
  s.description = 'The server runs 24-7, generates/deletes files and validates content at backup periodically.'
  s.authors     = ['Kolman Vornovitsky, Genady Petelko']
  s.email       = 'bbfsdev@gmail.com'
  s.homepage    = 'http://github.com/bbfsdev/bbfs'
  s.files       = Dir['lib/testing_server.rb', 'lib/testing_server/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/testing_server/**/*'] & `git ls-files -z`.split("\0")
  s.executables = ['testing_server']
  s.add_runtime_dependency('content_server', '>=1.0.3')
  s.add_runtime_dependency('content_data', '>=1.0.1')
  s.add_runtime_dependency('email', '>=1.0.1')
  s.add_runtime_dependency('file_utils', '>=1.0.1')
  s.add_runtime_dependency('log', '>=1.0.1')
  s.add_runtime_dependency('networking', '>=1.0.1')
  s.add_runtime_dependency('params', '>=1.0.2')
  s.add_runtime_dependency('run_in_background', '>=1.0.1')
  s.add_runtime_dependency('validations', '>=1.0.1')
  s.add_dependency('content_server', '>=1.0.3')
  s.add_dependency('content_data', '>=1.0.1')
  s.add_dependency('email', '>=1.0.1')
  s.add_dependency('file_utils', '>=1.0.1')
  s.add_dependency('log', '>=1.0.1')
  s.add_dependency('networking', '>=1.0.1')
  s.add_dependency('params', '>=1.0.2')
  s.add_dependency('run_in_background', '1.0.1')
  s.add_dependency('validations', '>=1.0.1')
end
