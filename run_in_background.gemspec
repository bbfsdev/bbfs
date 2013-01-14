require File.expand_path('../lib/run_in_background/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'run_in_background'
  s.version     = BBFS::RunInBackground::VERSION
  s.summary     = 'Cross-platform library for daemons management.'
  s.description = "This library provides a basic cross-platform functionality to run" \
                  "arbitrary ruby scripts in background and control them." \
                  "Supported platforms: Windows, Linux, Mac."
  s.authors     = ['Genady Petelko']
  s.email       = 'nukegluk@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = Dir['lib/run_in_background.rb', 'lib/run_in_background/**/*', 'bin/run_in_background/daemon_wrapper'] \
                  & `git ls-files -z`.split("\0")
  s.test_files  = Dir['test/run_in_background/**/*'] & `git ls-files -z`.split("\0")
  s.add_dependency('log')
  s.add_dependency('params')
#  Add platform dependant gems via extension
#    Linux dependencies: daemons
#    Windows dependencies: win32-service, sys-uname
  s.extensions = ['ext/run_in_background/mkrf_conf.rb']
  # Shouldn't be run from comman line, thus commented
  # s.executables << 'run_in_background/daemon_wrapper'  
end
