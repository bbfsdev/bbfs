require File.expand_path('../lib/content_data/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'content_data'
  s.version     = BBFS::ContentData::VERSION
  s.summary     = 'Data structure for an abstract layer over files.'
  s.description = 'Data structure for an abstract layer over files. Each binary sequence is a '
                  'content, each file is content instance.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/content_data.rb', 'lib/content_data/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['test/content_data/**/*'] & `git ls-files -z`.split("\0")
  s.add_dependency('log')
  s.add_dependency('params')
end
