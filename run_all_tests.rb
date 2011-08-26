# TODO(kolman): This file should run all tests!!!
# Tests should be loaded dynamically, i.e. not hard coded
# That way when adding new test no changed here are needed.


require 'test/unit/ui/console/testrunner'
require 'test/unit/ui/tk/testrunner'
require 'test/unit'

@@root_dir = File.dirname(File.expand_path(__FILE__))

Dir["#{@@root_dir}/tests/*"].each do |testcase|
  require testcase
end


