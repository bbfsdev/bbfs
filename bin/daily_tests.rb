#TODO yarondbb Add time out for operations

require 'FileUtils'
#
#Unit Tests (Rake):
# Uninstall all Gems
# Retrieve the latest master from BBFS git repository
# Remove previous execution output file
# Create output Log Directory for test:
#  /tmp/daily_tests/unit_test/log/
# Create all needed Gems for tests (e.g. Bundler and Rake gem)
# Run Rake and redirect to /tmp/daily_tests/unit_test/log/rake.log
# Parse log and generate report
#
BBFS_GIT_REPO = 'https://github.com/bbfsdev/bbfs'
DAILY_TEST_DIR = File.join('C:/Users/ydror1','daily_tests')
BBFS_DIR = File.join(DAILY_TEST_DIR, 'bbfs')

UNIT_TEST_BASE_DIR = File.join(DAILY_TEST_DIR, 'unit_test')
UNIT_TEST_OUT_DIR = File.join(UNIT_TEST_BASE_DIR, 'log')
UNIT_TEST_OUT_FILE = File.join(UNIT_TEST_OUT_DIR, 'rake.log')

#output = `grep hosts /private/etc/* 2>&1`
def execute_command(command)
  puts "\n   Running command:'#{command}'"
  command_res = `#{command} 2>&1`  # this will redirect both stdout and stderr to stdout
  command_res.each_line { |line|
    chomped_line = line.chomp
    puts "      #{chomped_line}"
  }
  raise("Error occurred in command:#{command}") if command_res.match(/fatal|fail|error|aborted/i)
  command_res
end

def uninstall_all_gems
  puts "\n\nStart uninstall all gems"
  puts "-------------------------------------------------------------------"
  `gem list --no-versions`.each_line {|gem|
    gem_new = gem.chomp
    next if gem_new.length == 0
    execute_command("gem uninstall #{gem_new} -a -x -I")
    puts "   removed gem #{gem}"
  }
  puts "\nDone uninstall all gems"
end

def prepare_latest_bbfs_repo
  puts "\n\nStart removing bbfs dir:#{BBFS_DIR}"
  puts "-------------------------------------------------------------------"
  ::FileUtils.remove_dir(BBFS_DIR, true)  # true will force delete
  puts "\nDone removing bbfs dir:#{BBFS_DIR}"
  Dir.chdir(DAILY_TEST_DIR)
  puts "\n\nStart cloning bbfs from git repo:#{BBFS_GIT_REPO}"
  puts "-------------------------------------------------------------------"
  execute_command("git clone #{BBFS_GIT_REPO}")
  puts "\nDone cloning bbfs from git repo:#{BBFS_GIT_REPO}"
 end

# Create all needed Gems for tests (Bundler and Rake)
def unit_test_create_gems
  puts "\n\nStart install bundler gems"
  puts "-------------------------------------------------------------------"
  Dir.chdir(BBFS_DIR)
  execute_command('gem install bundler')
  execute_command('bundle install')
  puts "\nDone install bundler gems"
end


def unit_test_prepare_prev_inout_paths
  puts "\n\nUnit test: Start prepare prev inout paths"
  puts "-------------------------------------------------------------------"
  ::FileUtils.remove_dir(UNIT_TEST_OUT_DIR, true)  # true will force delete
  ::FileUtils.mkdir_p(UNIT_TEST_OUT_DIR)
  puts "   Cleared and Created out path:#{UNIT_TEST_OUT_DIR}"
  puts "\nUnit test: Done prepare prev inout paths"

end

# Run Rake and redirect to /tmp/daily_tests/unit_test/log/rake.log
def unit_test_execute
  puts "\n\nStart unit test execution"
  puts "-------------------------------------------------------------------"
  rake_output = execute_command("rake")
  File.open(UNIT_TEST_OUT_FILE,'w') { |file|
    file.puts(rake_output)
  }
end

def unit_test_parse_log

end

def unit_test_generate_report

end

def unit_test
  #uninstall_all_gems
  #prepare_latest_bbfs_repo
  #unit_test_prepare_prev_inout_paths
  #unit_test_create_gems
  unit_test_execute
  unit_test_parse_log
  unit_test_generate_report
end

begin
  unit_test
rescue => e
  puts "\nError caught. Msg:#{e.message}\nBack trace:#{e.backtrace}"
end


