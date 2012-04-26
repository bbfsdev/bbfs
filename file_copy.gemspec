require File.expand_path('../lib/file_copy/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'file_copy'
  s.version     = BBFS::FileCopy::VERSION
  s.summary     = 'Library for copying files remotely.'
  s.description = 'Library for copying files to remote servers.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = ['lib/file_copy.rb',
                   'lib/file_copy/copy.rb']
  s.test_files  = ['test/file_copy/copy_spec.rb']
end
