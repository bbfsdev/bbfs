require File.expand_path('../lib/file_indexing/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'file_indexing'
  s.version     = FileIndexing::VERSION
  s.summary     = 'Indexes files.'
  s.description = 'Indexes files, treats files with same binary sequence as one content.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/file_indexing.rb', 'lib/file_indexing/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/file_indexing/**/*', 'test/file_indexing/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.add_dependency('content_data')
  s.add_dependency('log')
  s.add_dependency('params')
end
