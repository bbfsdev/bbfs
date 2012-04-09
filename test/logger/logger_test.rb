require ("./logger.rb")
require 'test/unit'

class TestLogger < Test::Unit::TestCase
  def test_params_read
    logger = MyLogger.new('test-logger','log1.txt')
    assert_equal('test-logger',logger.name)
    assert_equal('log1.txt',logger.fileName)
    assert_equal(0,logger.debugLevel)
    logger.closeLogger()
  end

  def test_write_log_to_file_and_compare_with_expected_file
    #init logger
    logger = MyLogger.new('test-logger','log1.txt')
    #start write ot file using all write methods using level 0
    logger.logInfo("this is a test info message level 0")
    logger.logError("this is a test error message level 0")
    logger.logWarning("this is a test warning message level 0")
    logger.logDebug1("this is a test debug 1 message level 0")
    logger.logDebug2("this is a test debug 2 message level 0")
    logger.logDebug3("this is a test debug 3 message level 0")
    #start write ot file using all write methods using level 1
    logger.debugLevel = 1
    logger.logInfo("this is a test info message level 1")
    logger.logError("this is a test error message level 1")
    logger.logWarning("this is a test warning message level 1")
    logger.logDebug1("this is a test debug 1 message level 1")
    logger.logDebug2("this is a test debug 2 message level 1")
    logger.logDebug3("this is a test debug 3 message level 1")
    #start write ot file using all write methods using level 2
    logger.debugLevel = 2
    logger.logInfo("this is a test info message level 2")
    logger.logError("this is a test error message level 2")
    logger.logWarning("this is a test warning message level 2")
    logger.logDebug1("this is a test debug 1 message level 2")
    logger.logDebug2("this is a test debug 2 message level 2")
    logger.logDebug3("this is a test debug 3 message level 2")
    #start write ot file using all write methods using level 3
    logger.debugLevel = 3
    logger.logInfo("this is a test info message level 3")
    logger.logError("this is a test error message level 3")
    logger.logWarning("this is a test warning message level 3")
    logger.logDebug1("this is a test debug 1 message level 3")
    logger.logDebug2("this is a test debug 2 message level 3")
    logger.logDebug3("this is a test debug 3 message level 3")
    logger.closeLogger()
    #Check that log is as expected.Compare the log file with expected file
    assert_equal(0,File.readlines("./log1.txt") <=> File.readlines("./compareWithLog1.txt"))
  end
end


