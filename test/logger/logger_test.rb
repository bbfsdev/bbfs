require ('./logger.rb')
require ('./params.rb')
require 'test/unit'

module BBFS
  class TestLogger < Test::Unit::TestCase

    def test_write_log_to_file_and_compare_with_expected_file
      PARAMS.logger_debug_level = 0
      #start write ot file using all write methods using level 0
      Logger.logInfo("this is a test info message level 0")
      Logger.logError("this is a test error message level 0")
      Logger.logWarning("this is a test warning message level 0")
      Logger.logDebug1("this is a test debug 1 message level 0")
      Logger.logDebug2("this is a test debug 2 message level 0")
      Logger.logDebug3("this is a test debug 3 message level 0")
      #start write ot file using all write methods using level 1
      PARAMS.logger_debug_level = 1
      Logger.logInfo("this is a test info message level 1")
      Logger.logError("this is a test error message level 1")
      Logger.logWarning("this is a test warning message level 1")
      Logger.logDebug1("this is a test debug 1 message level 1")
      Logger.logDebug2("this is a test debug 2 message level 1")
      Logger.logDebug3("this is a test debug 3 message level 1")
      #start write ot file using all write methods using level 2
      PARAMS.logger_debug_level = 2
      Logger.logInfo("this is a test info message level 2")
      Logger.logError("this is a test error message level 2")
      Logger.logWarning("this is a test warning message level 2")
      Logger.logDebug1("this is a test debug 1 message level 2")
      Logger.logDebug2("this is a test debug 2 message level 2")
      Logger.logDebug3("this is a test debug 3 message level 2")
      #start write ot file using all write methods using level 3
      PARAMS.logger_debug_level = 3
      Logger.logInfo("this is a test info message level 3")
      Logger.logError("this is a test error message level 3")
      Logger.logWarning("this is a test warning message level 3")
      Logger.logDebug1("this is a test debug 1 message level 3")
      Logger.logDebug2("this is a test debug 2 message level 3")
      Logger.logDebug3("this is a test debug 3 message level 3")
      Logger.closeLogger()
      #Check that log is as expected.Compare the log file with expected file
      assert_equal(0,File.readlines("./log1.txt") <=> File.readlines("./compareWithLog1.txt"))
    end
  end
end



