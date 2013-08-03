require File.expand_path('../lib/file_utils/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'file_utils'
  s.version     = FileUtils::VERSION
  s.summary     = 'Executable for operating on bbfs files.'
  s.description = 'Executable for operating on bbfs files, locally and remotely.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'bbfsdev@gmail.com'
  s.homepage    = 'http://github.com/bbfsdev/bbfs'
  s.files       = Dir['lib/file_utils.rb', 'lib/file_utils/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/file_utils/**/*', 'test/file_utils/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.executables = ['file_utils']
  s.add_dependency('log')
  s.add_dependency('params')
end
