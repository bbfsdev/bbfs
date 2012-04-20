Gem::Specification.new do |s|
  s.name        = 'file_monitoring_win32'
  s.version     = '0.0.1'
  s.date        = '2012-01-28'
  s.summary     = "Windows Service for monitoring file changes."
  s.description = "Windows Service for monitoring file changes."
  s.authors     = ["Gena Petelko, Kolman Vornovitsky"]
  s.email       = 'kolmanv@gmail.com'
  s.files       = ["lib/file_monitoring/file_monitoring.rb",
                   "lib/file_monitoring/monitor_path.rb",
                   "lib/file_monitoring/daemon_win32.rb"]
  s.executables << 'file_monitoring_win32'
  s.add_dependency("algorithms")
  s.add_dependency('win32-service')
  s.require_paths << 'lib'
end
