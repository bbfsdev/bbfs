require File.expand_path('../lib/validations/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'validations'
  s.version     = Validations::VERSION
  s.summary     = 'Library for validating data.'
  s.description = 'Used to validate ContentData objects.'
  s.authors     = ['Genady Petelko']
  s.email       = 'nukegluk@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/validations.rb', 'lib/validations/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.executables = ['index_validator']
  s.test_files  = Dir['spec/validations/**/*', 'test/validations/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.add_dependency('log')
  s.add_dependency('params')
  s.add_dependency('content_data')
  s.add_dependency('file_indexing')
end
