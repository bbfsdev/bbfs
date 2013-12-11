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
  $log_file.puts("\n   Running command:'#{command}'")
  command_res = `#{command} 2>&1`  # this will redirect both stdout and stderr to stdout
  command_res.each_line { |line|
    chomped_line = line.chomp
    $log_file.puts("      #{chomped_line}")
  }
  raise("Error occurred in command:#{command}") if command_res.match(/fatal|fail|error|aborted/i) if raise_error
  command_res
end

def uninstall_all_gems
  $log_file.puts("\n\nStart uninstall all gems")
  $log_file.puts("-------------------------------------------------------------------")
  `gem list --no-versions`.each_line {|gem|
    gem_new = gem.chomp
    next if gem_new.length == 0
    execute_command("gem uninstall #{gem_new} -a -x -I")
    $log_file.puts("   removed gem #{gem}")
  }
  $log_file.puts("\nDone uninstall all gems")
end

def update_dirs(time)
  unless Gem::win_platform?
    $DAILY_TEST_DIR = File.join('/tmp','daily_tests', time.to_s)
  else
    $DAILY_TEST_DIR = File.join(File.expand_path('~'),'daily_tests', time.to_s)  #for Windows
  end
  $DAILY_TEST_LOG_DIR = File.join($DAILY_TEST_DIR, 'log')
  $DAILY_TEST_LOG_FILE = File.join($DAILY_TEST_LOG_DIR, 'daily_test.log')
  $BBFS_DIR = File.join($DAILY_TEST_DIR, 'bbfs')
  $UNIT_TEST_BASE_DIR = File.join($DAILY_TEST_DIR, 'unit_test')
  $UNIT_TEST_OUT_DIR = File.join($UNIT_TEST_BASE_DIR, 'log')
  $UNIT_TEST_OUT_FILE = File.join($UNIT_TEST_OUT_DIR, 'rake.log')
end

def prepare_daily_test_dirs
  puts("\n\nStart preparing daily test dir:#{$DAILY_TEST_DIR}")
  puts("-------------------------------------------------------------------")
  #::FileUtils.remove_dir($DAILY_TEST_DIR, true)  # true will force delete
  ::FileUtils.mkdir_p($DAILY_TEST_DIR) unless File.exist?($DAILY_TEST_DIR)
  ::FileUtils.mkdir_p($DAILY_TEST_LOG_DIR)
  puts("\nDone removing and creating bbfs dir:#{$DAILY_TEST_DIR}")
end

def clone_bbfs_repo
  Dir.chdir($DAILY_TEST_DIR)
  $log_file.puts("\n\nStart cloning bbfs from git repo:#{BBFS_GIT_REPO}")
  $log_file.puts("-------------------------------------------------------------------")
  execute_command("git clone #{BBFS_GIT_REPO}")
  $log_file.puts("\nDone cloning bbfs from git repo:#{BBFS_GIT_REPO}")
  Dir.chdir($BBFS_DIR)
end

# Create all needed Gems for tests (Bundler and Rake)
def unit_test_create_gems
  $log_file.puts("\n\nStart install bundler gems")
  $log_file.puts("-------------------------------------------------------------------")
  execute_command('gem install bundler')
  execute_command('bundle install')
  $log_file.puts("\nDone install bundler gems")
end


def unit_test_prepare_prev_inout_paths
  $log_file.puts("\n\nUnit test: Start prepare prev inout paths")
  $log_file.puts("-------------------------------------------------------------------")
  #::FileUtils.remove_dir($UNIT_TEST_OUT_DIR, true)  # true will force delete
  ::FileUtils.mkdir_p($UNIT_TEST_OUT_DIR)
  $log_file.puts("   Cleared and Created out path:#{$UNIT_TEST_OUT_DIR}")
  $log_file.puts("\nUnit test: Done prepare prev inout paths")
end

# Run Rake and redirect to /tmp/daily_tests/unit_test/log/rake.log
def unit_test_execute
  $log_file.puts("\n\nStart unit test execution")
  $log_file.puts("-------------------------------------------------------------------")
  rake_output = execute_command("rake", false)
  File.open($UNIT_TEST_OUT_FILE,'w') { |file|
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
  pass_counter = 0
  rake_output.each_line { |line|
    chomped_line = line.chomp
    # Check Rake Test
    if chomped_line.match(/\d+ failures, \d+ errors, \d+ skips/)
      pass_counter += 1
      if chomped_line.match(/0 failures, 0 errors, 0 skips/)
        report += "   Rake Test is OK. Description: #{chomped_line}\n"
      else
        report += "   Rake Test is NOT OK. Description: #{chomped_line}\n"
      end
      # Check Rake Spec
    elsif chomped_line.match(/examples, \d+ failures/)
      pass_counter += 1
      if chomped_line.match(/examples, 0 failures/)
        report += "   Rake Spec is OK. Description: #{chomped_line}\n"
      else
        report += "   Rake Spec is NOT OK. Description:#{chomped_line}\n"
      end
    end
  }
  if pass_counter != 2
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
Unit Test log can be found at: #{$DAILY_TEST_LOG_FILE}
Rake command output can be found at: #{$UNIT_TEST_OUT_FILE}
Results:
#{report}
EOF
  Email.send_email(TO_EMAIL, FROM_EMAIL_PASSWORD, FROM_EMAIL, 'Daily system report', mail_body)
  $log_file.puts("   Unit test report sent to:#{TO_EMAIL}")
end

def unit_test

  # init log
  $log_file = File.open($DAILY_TEST_LOG_FILE, 'w')
  puts("\nRest of log can be found in: #{$DAILY_TEST_LOG_FILE}")
  # from now on log file will be used by methods

  clone_bbfs_repo
  uninstall_all_gems
  unit_test_prepare_prev_inout_paths
  unit_test_create_gems
  rake_output = unit_test_execute
  report = unit_test_parse_log(rake_output)
  unit_test_generate_report(report)
  $log_file.close

end

begin
  puts("Start Daily tests")
  loop {
    time_now = Time.now
    current_hour = time_now.hour
    current_minutes = time_now.min
    current_seconds = time_now.sec
    #Time since 00:00:00 of this day
    seconds_from_midnight = current_seconds + current_minutes * 60 + current_hour * 3600
    seconds_till_midnight = 24*3600 - seconds_from_midnight
    puts("Time is:#{time_now}. sleeping till midnight: #{seconds_till_midnight}[S]")
    sleep(seconds_till_midnight)

    #start at midnight
    time_now = Time.now
    puts("Wake at #{time_now} and Start Daily test execution")
    update_dirs("#{time_now.year}_#{time_now.month}_#{time_now.day}")
    prepare_daily_test_dirs  # this will use puts to console
    unit_test
  }
rescue => e
  puts("\nError caught. Msg:#{e.message}\nBack trace:#{e.backtrace}")
  $log_file.puts("\nError caught. Msg:#{e.message}\nBack trace:#{e.backtrace}")
  $log_file.close
end
