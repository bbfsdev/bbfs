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

def uninstall_all_gems
  `gem list --no-versions`.each_line {|gem|
    puts "gem to uninstall #{gem}"
    `gem uninstall #{gem} -a -x -I`
    puts "removed gem #{gem}"
  }
end

def prepare_latest_bbfs
end

def unit_test
  uninstall_all_gems
  prepare_latest_bbfs
  # Retrieve the latest master from BBFS git repository
  # Remove previous execution output file
  # Create output Log Directory for test:
  #  /tmp/daily_tests/unit_test/log/
  # Create all needed Gems for tests (e.g. Bundler and Rake gem)
  # Run Rake and redirect to /tmp/daily_tests/unit_test/log/rake.log
  # Parse log and generate report

end

begin
  `dir`.each_line {|dir|
    puts "puts:#{dir}"
  `echo #{dir.to_s}`
    break
  }
  unit_test
rescue => e
  puts "Error caught. Msg:#{e.message}\nBack trace:#{e.backtrace}"
end


