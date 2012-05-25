require File.expand_path('../lib/run_in_background/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'run_in_background'
  s.version     = BBFS::RunInBackground::VERSION
  s.summary     = 'Cross-platform library for daemons management.'
s.description = <<-EOF
This library provides a basic cross-platform functionality to run
arbitrary ruby scripts in background and control them.
Supported platforms: Windows, Linux, Mac.
EOF
  s.authors     = ['Genady Petelko']
  s.email       = 'nukegluk@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = ['lib/run_in_background.rb', 'bin/run_in_background/daemon_wrapper']
  s.test_files  = ['test/run_in_background/run_in_background_test.rb', 
                   'test/run_in_background/test_app']
  # Shouldn't be run from comman line
  # #s.executables << 'run_in_background/daemon_wrapper'  
end
