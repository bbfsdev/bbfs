require File.expand_path('../lib/validations/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'validations'
  s.version     = FileCopy::VERSION
  s.summary     = 'Gem for validating indexes local and remote.'
  s.description = 'Gem for validating indexes local and remote.'
  s.authors     = ['Gena Petelko']
  s.email       = 'nukegluk@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/validations.rb', 'lib/validations/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.executables = ['index_validator']
end
