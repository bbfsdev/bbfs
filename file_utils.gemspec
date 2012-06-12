require File.expand_path('../lib/file_utils/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'file_utils'
  s.version     = BBFS::FileUtils::VERSION
  s.summary     = 'Executable for operating on bbfs files.'
  s.description = 'Executable for operating on bbfs files, locally and remotely.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = ['lib/file_utils.rb',
                   'lib/file_utils/file_utils.rb',
                   'lib/file_utils/file_generator/file_generator.rb',
                   'lib/file_utils/file_generator/README']
  #s.test_files  = ['test/file_utils/file_utils_spec.rb']
  s.executables = ['file_utils']
end
