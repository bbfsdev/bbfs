require File.expand_path('../lib/content_server/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'content_server'
  s.version     = ContentServer::VERSION
  s.summary     = 'Servers for backing up content.'
  s.description = 'Monitor and Index a directory and back it up to backup server.'
                  'Backups content as opposed to files. Two identical files are considered'
                  ' one content if they have same bits sequence.'
  s.authors     = ['BBFS Team']
  s.email       = 'bbfsdev@gmail.com'
  s.homepage    = 'http://github.com/bbfsdev/bbfs'

  s.files       = Dir['lib/content_data.rb', 'lib/content_data/**/*',
    'lib/content_server.rb', 'lib/content_server/**/*',
    'lib/email.rb', 'lib/email/**/*',
    'lib/file_copy.rb', 'lib/file_copy/**/*',
    'lib/file_indexing.rb', 'lib/file_indexing/**/*',
    'lib/file_monitoring.rb', 'lib/file_monitoring/**/*',
    'lib/file_utils.rb', 'lib/file_utils/**/*',
    'lib/log.rb', 'lib/log/**/*',
    'lib/networking.rb', 'lib/networking/**/*',
    'lib/params.rb', 'lib/params/**/*',
    'lib/process_monitoring.rb', 'lib/process_monitoring/**/*',
    'lib/run_in_background.rb', 'lib/run_in_background/**/*',
    'lib/testing_server.rb', 'lib/testing_server/**/*',
    'lib/testing_memory/**/*',
    'lib/validations.rb', 'lib/validations/**/*'] \
    & `git ls-files -z`.split("\0")
  s.test_files  = Dir['test/content_data/**/*',
    'test/file_generator/**/*',
    'test/file_indexing/**/*',
    'test/file_monitoring/**/*',
    'test/file_utils/**/*',
    'test/params/**/*',
    'test/run_in_background/**/*',
    'spec/content_data/**/*',
    'spec/content_server/**/*',
    'spec/file_copy/**/*',
    'spec/file_indexing/**/*',
    'spec/networking/**/*',
    'spec/validations/**/*'] \
    & `git ls-files -z`.split("\0")

  s.executables = ['content_server', 'backup_server', 'file_utils', 'testing_server', 'testing_memory']

  # used by content_server, run_in_background
  s.add_runtime_dependency('rake', '0.9.2.2')
  # used by file_monitoring
  s.add_runtime_dependency('algorithms')
  # used by log
  s.add_runtime_dependency('log4r')
  # used by process_monitoring
  s.add_runtime_dependency('eventmachine')
  # used by process_monitoring
  s.add_runtime_dependency('json')
  # used by process_monitoring
  s.add_runtime_dependency('sinatra')
  # used by process_monitoring
  s.add_runtime_dependency('thin')

  s.add_dependency('rake', '0.9.2.2')
  s.add_dependency('algorithms')
  s.add_dependency('log4r')
  s.add_dependency('eventmachine')
  s.add_dependency('json')
  s.add_dependency('sinatra')
  s.add_dependency('thin')

#  Add platform dependant gems via extension (used by run_in_background).
#    Linux dependencies: daemons
#    Windows dependencies: win32-service, sys-uname
  s.extensions = ['ext/run_in_background/mkrf_conf.rb']
end
