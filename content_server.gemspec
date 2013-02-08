require File.expand_path('../lib/content_server/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'content_server'
  s.version     = ContentServer::VERSION
  s.summary     = 'Servers for backing up content.'
  s.description = 'Monitor and Index a directory and back it up to backup server.'
                  'Backups content as opposed to files. Two identical files are considered'
                  ' one content if they have same bits sequence.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/content_server.rb', 'lib/content_server/**/*'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['spec/content_server/**/*'] & `git ls-files -z`.split("\0")
  s.executables = ['content_server', 'backup_server']
  s.add_dependency('content_data')
#  s.add_dependency('eventmachine')
  s.add_dependency('file_indexing')
  s.add_dependency('file_monitoring')
  s.add_dependency('log')
  s.add_dependency('networking')
  s.add_dependency('params')
  s.add_dependency('run_in_background')
end
