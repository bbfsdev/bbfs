Gem::Specification.new do |s|
  s.name        = 'file_copy'
  s.version     = '0.0.2'
  s.summary     = 'Library for copying files remotely.'
  s.description = 'Library for copying files to remote servers.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = ['lib/file_copy.rb',
                   'lib/file_copy/copy.rb']
  s.test_files  = ['test/file_copy/copy_spec.rb']
end
