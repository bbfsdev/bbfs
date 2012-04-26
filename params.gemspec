require File.expand_path('../lib/params/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'params'
  s.version     = BBFS::Params::VERSION
  s.summary     = 'Dynamically stores, parses and providers params.'
  s.description = 'Dynamically stores, parses and providers params. Uses module local readers.'
  s.authors     = ['Gena Petelko', 'Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = ['lib/params.rb',
                   'lib/params/argument_parser.rb']
#  s.test_files  = ['test/params/params_spec.rb']
end
