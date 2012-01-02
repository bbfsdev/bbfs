Gem::Specification.new do |s|
  s.name        = 'file_monitoring'
  s.version     = '0.0.0'
  s.date        = '2012-12-30'
  s.summary     = "Deamon for monitoring file changes."
  s.description = "Deamon for monitoring file changes."
  s.authors     = ["Gena Petelko, Kolman Vornovitsky"]
  s.email       = 'kolmanv@gmail.com'
  s.files       = ["lib/file_monitoring/file_monitoring.rb",
                   "lib/file_monitoring/monitor_path.rb"]
  s.executables << 'file_monitoring'
  s.add_dependency("algorithms")
  s.add_dependency("daemons")
  s.add_dependency("FileUtils")
end