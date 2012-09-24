# this extension used to install platform specific gem dependencies
# for more information:
#     http://stackoverflow.com/questions/4596606/rubygems-how-do-i-add-platform-specific-dependency/10249133#10249133
#     https://github.com/openshift/os-client-tools/blob/master/express/ext/mkrf_conf.rb

require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'
#begin
#Gem::Command.build_args = ARGV
#rescue NoMethodError
#end
inst = Gem::DependencyInstaller.new
begin
  if Gem::win_platform?
    if Gem::Specification.find_all_by_name('sys-uname').empty?
      inst.install 'sys-uname'
    end
    if Gem::Specification.find_all_by_name('win32-service').empty?
      inst.install 'win32-service'
    end
  else
    if Gem::Specification.find_all_by_name('daemons').empty?
      inst.install 'daemons'
    end
  end
rescue Exception => e
  puts e.to_s
  exit(1)
end

f = File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w")   # create dummy rakefile to indicate success
f.write("task :default\n")
f.close
