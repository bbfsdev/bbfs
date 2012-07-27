require 'rubygems'
require 'rake'

desc 'Default: run specs and tests.'
task :default => [:test, :spec]

desc 'Builds the gem'
task :build do
  FileList['*.gemspec'].each { |gemspec|
    sh "gem build #{gemspec}"
  }
end

desc 'Builds and installs the gem'
task :install => :build do
  FileList['*.gem'].each { |gem|
    sh "gem install #{gem}"
  }
end

desc 'Unistall gems'
task :uninstall do
  FileList['*.gem'].each { |gem|
    sh "echo | gem uninstall #{gem[/[^-]*/]}"
  }
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << 'test' << 'spec'
  t.test_files = FileList['./test/**/*_test.rb']
  t.verbose = true
end

require 'rspec/core/rake_task'
desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = ["./test/**/*_spec.rb", "./spec/**/*_spec.rb"]
end

#Spec::Rake::SpecTask.new do |t|
#  t.libs << 'lib'
#end
