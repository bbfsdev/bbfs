require File.expand_path('../lib/file_copy/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'file_copy'
  s.version     = FileCopy::VERSION
  s.summary     = 'Library for copying files remotely.'
  s.description = 'Library for copying files to remote servers.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/file_copy.rb', 'lib/file_copy/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/file_copy/**/*'] & `git ls-files -z`.split("\0")
end
