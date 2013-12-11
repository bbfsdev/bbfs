#TODO yarondbb Add time out for operations

require 'email'
require 'fileutils'

#################################################################
#Unit Tests (Rake):
# Uninstall all Gems
# Retrieve the latest master from BBFS git repository
# Remove previous execution output file
# Create output Log Directory for test:
#  /tmp/daily_tests/unit_test/log/
# Create all needed Gems for tests (e.g. Bundler and Rake gem)
# Run Rake and redirect to /tmp/daily_tests/unit_test/log/rake.log
# Parse log and generate report
###################################################################

# ------------------------------------------------- Definitions ---------------------------
BBFS_GIT_REPO = 'https://github.com/bbfsdev/bbfs'
unless Gem::win_platform?
  DAILY_TEST_DIR = File.join('/tmp','daily_tests')
else
  DAILY_TEST_DIR = File.join(File.expand_path('~'),'daily_tests')  #for Windows
end
DAILY_TEST_LOG_DIR = File.join(DAILY_TEST_DIR, 'log')
DAILY_TEST_LOG_FILE = File.join(DAILY_TEST_LOG_DIR, 'daily_test.log')
BBFS_DIR = File.join(DAILY_TEST_DIR, 'bbfs')
UNIT_TEST_BASE_DIR = File.join(DAILY_TEST_DIR, 'unit_test')
UNIT_TEST_OUT_DIR = File.join(UNIT_TEST_BASE_DIR, 'log')
UNIT_TEST_OUT_FILE = File.join(UNIT_TEST_OUT_DIR, 'rake.log')
FROM_EMAIL = ARGV[0]
FROM_EMAIL_PASSWORD = ARGV[1]
TO_EMAIL = ARGV[2]

$log_file = nil  # will be initialized later

# execute_command Algorithm:
#   executing shell commands. if stdout and\or stderr has the
#   strings: fatal|fail|error|aborted an error will be raised
# Parameters:
#   in: command - the comand to execute
#   in: raise_error - if false then if stdout and\or stderr has the
#                     strings: fatal|fail|error|aborted they will not raise an error.
#                     Used for 'rake' command where the string error is used but it does not indicate an error
# Returns: Stdout and Stderr of the command
def execute_command(command, raise_error=true)
  puts "\n   Running command:'#{command}'"
  command_res = `#{command} 2>&1`  # this will redirect both stdout and stderr to stdout
  command_res.each_line { |line|
    chomped_line = line.chomp
    puts "      #{chomped_line}"
  }
  raise("Error occurred in command:#{command}") if command_res.match(/fatal|fail|error|aborted/i) if raise_error
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



def prepare_daily_test_dirs
  puts("\n\nStart removing and creating daily test dir:#{DAILY_TEST_DIR}")
  puts("-------------------------------------------------------------------")
  ::FileUtils.remove_dir(DAILY_TEST_DIR, true)  # true will force delete
  ::FileUtils.mkdir_p(DAILY_TEST_DIR)
  ::FileUtils.mkdir_p(DAILY_TEST_LOG_DIR)
  puts("\nDone removing and creating bbfs dir:#{DAILY_TEST_DIR}")
  Dir.chdir(DAILY_TEST_DIR)
  $log_file = File.open(DAILY_TEST_LOG_FILE, 'w')
  puts("\nRest of log can be found in: #{DAILY_TEST_LOG_FILE}")
  $log_file.puts("\n\nStart cloning bbfs from git repo:#{BBFS_GIT_REPO}")
  $log_file.puts("-------------------------------------------------------------------")
  execute_command("git clone #{BBFS_GIT_REPO}")
  $log_file.puts("\nDone cloning bbfs from git repo:#{BBFS_GIT_REPO}")
end

# Create all needed Gems for tests (Bundler and Rake)
def unit_test_create_gems
  $log_file.puts("\n\nStart install bundler gems")
  $log_file.puts("-------------------------------------------------------------------")
  Dir.chdir(BBFS_DIR)
  execute_command('gem install bundler')
  execute_command('bundle install')
  $log_file.puts("\nDone install bundler gems")
end


def unit_test_prepare_prev_inout_paths
  $log_file.puts("\n\nUnit test: Start prepare prev inout paths")
  $log_file.puts("-------------------------------------------------------------------")
  ::FileUtils.remove_dir(UNIT_TEST_OUT_DIR, true)  # true will force delete
  ::FileUtils.mkdir_p(UNIT_TEST_OUT_DIR)
  $log_file.puts("   Cleared and Created out path:#{UNIT_TEST_OUT_DIR}")
  $log_file.puts("\nUnit test: Done prepare prev inout paths")
end

# Run Rake and redirect to /tmp/daily_tests/unit_test/log/rake.log
def unit_test_execute
  $log_file.puts("\n\nStart unit test execution")
  $log_file.puts("-------------------------------------------------------------------")
  rake_output = execute_command("rake", false)
  File.open(UNIT_TEST_OUT_FILE,'w') { |file|
    file.puts(rake_output)
  }
  rake_output
end


def unit_test_parse_log(rake_output)
  # format of Test is:
  #   18 tests, 96 assertions, 0 failures, 0 errors, 0 skips
  # format of Spec is:
  #   42 examples, 0 failures
  report = ''
  rake_output.each_line { |line|
    chomped_line = line.chomp
    # Check Rake Test
    if chomped_line.match(/\d+ failures, \d+ errors, \d+ skips/)
      if chomped_line.match(/0 failures, 0 errors, 0 skips/)
        report += "   Rake Test is OK. Description: #{chomped_line}\n"
      else
        report += "   Rake Test is NOT OK. Description: #{chomped_line}\n"
      end
      # Check Rake Spec
    elsif chomped_line.match(/examples, \d+ failures/)
      if chomped_line.match(/examples, 0 failures/)
        report += "   Rake Spec is OK. Description: #{chomped_line}\n"
      else
        report += "   Rake Spec is NOT OK. Description:#{chomped_line}\n"
      end
    end
  }
  if report.each_line.length != 2
    $log_file.puts("\n   Problem with parsing Rake log. Could not find status 2 lines")
  else
    $log_file.puts("\n   Rake report summary:\n   -----------------------\n#{report}")
  end
  report
end

def unit_test_generate_report(report)
  mail_body =<<EOF
1. Unit test report
---------------------------------
Unit Test log can be found at: #{DAILY_TEST_LOG_FILE}
Rake command output can be found at: #{UNIT_TEST_OUT_FILE}
Results:
#{report}
EOF
  Email.send_email(TO_EMAIL, FROM_EMAIL_PASSWORD, FROM_EMAIL, 'Daily system report', mail_body)
  $log_file.puts("   Unit test sent to:#{TO_MAIL}")
end

def unit_test
  uninstall_all_gems
  prepare_daily_test_dirs
  # init log
  $log_file = File.open(DAILY_TEST_LOG_FILE, 'w')
  unit_test_prepare_prev_inout_paths
  unit_test_create_gems
  rake_output = unit_test_execute
  report = unit_test_parse_log(rake_output)
  unit_test_generate_report(report)
  $log_file.close
end

begin
  unit_test
rescue => e
  puts("\nError caught. Msg:#{e.message}\nBack trace:#{e.backtrace}")
  $log_file.puts("\nError caught. Msg:#{e.message}\nBack trace:#{e.backtrace}")
  $log_file.close
end
