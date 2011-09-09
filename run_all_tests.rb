
require 'test/unit'

@@root_dir = File.dirname(File.expand_path(__FILE__))

Dir["#{@@root_dir}/tests/*"].each do |testcase|
  require testcase
end


