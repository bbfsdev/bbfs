require ('./log.rb')
require ('./params.rb')
require 'test/unit'

module BBFS
  class TestLog < Test::Unit::TestCase

    def test_check_info_format
      #set test phase
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      testTime = Time.now
      Log.logInfo 'This is a test INFO message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,2,"2 lines (1 header message and 1 info message) should be found. Test found:#{messagesDB.size}"
      #check expected format: [BBFS LOG] [Time] [INFO] [log_test.rb:11] [This is a test INFO message.]
      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'INFO'
        assert_equal matchContainer.captures[3],'log_test.rb:12'
        assert_equal matchContainer.captures[4],'This is a test INFO message.'
      end
    end

    def test_check_warning_format
      #set test phase
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      testTime = Time.now
      Log.logWarning 'This is a test WARNING message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,2,"2 lines (1 header message and 1 warning message) should be found. Test found:#{messagesDB.size}"
      #check expected format: [BBFS LOG] [Time] [WARNING] [log_test.rb:35] [This is a test WARNING message.]
      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'WARNING'
        assert_equal matchContainer.captures[3],'log_test.rb:33'
        assert_equal matchContainer.captures[4],'This is a test WARNING message.'
      end
    end

    def test_check_error_format
      #set test phase
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      testTime = Time.now
      Log.logError 'This is a test ERROR message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,2,"2 lines (1 header message and 1 error message) should be found. Test found:#{messagesDB.size}"
      #check expected format: [BBFS LOG] [Time] [ERROR] [log_test.rb:35] [This is a test ERROR message.]
      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'ERROR'
        assert_equal matchContainer.captures[3],'log_test.rb:54'
        assert_equal matchContainer.captures[4],'This is a test ERROR message.'
      end
    end

    def test_check_debug_level_0
      #set test phase
      PARAMS.log_debug_level = 0
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      Log.logDebug1 'This is a test debug-1 message.'
      Log.logDebug2 'This is a test debug-2 message.'
      Log.logDebug3 'This is a test debug-3 message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,1,"At debug level 0, no debug messages should be found. 1 header message should be found. Test found:#{messagesDB.size} messages"
    end

    def test_check_debug_level_1
      #set test phase
      testTime = Time.now
      PARAMS.log_debug_level = 1
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      Log.logDebug1 'This is a test DEBUG-1 message.'
      Log.logDebug2 'This is a test DEBUG-2 message.'
      Log.logDebug3 'This is a test DEBUG-3 message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,2,"At debug level 1, 2 lines (1 header line and 1 debug message) should be found. Test found:#{messagesDB.size} messages"
      #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] [This is a test ERROR message.]
      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'DEBUG-1'
        assert_equal matchContainer.captures[3],'log_test.rb:89'
        assert_equal matchContainer.captures[4],'This is a test DEBUG-1 message.'
      end
    end

    def test_check_debug_level_2
      #set test phase
      testTime = Time.now
      PARAMS.log_debug_level = 2
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      Log.logDebug1 'This is a test DEBUG-1 message.'
      Log.logDebug2 'This is a test DEBUG-2 message.'
      Log.logDebug3 'This is a test DEBUG-3 message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,3,"At debug level 2, 3 lines (1 header line and 2 debug message) should be found. Test found:#{messagesDB.size} messages"
      #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] [This is a test ERROR message.]
      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'DEBUG-1'
        assert_equal matchContainer.captures[3],'log_test.rb:113'
        assert_equal matchContainer.captures[4],'This is a test DEBUG-1 message.'
      end

      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[2])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'DEBUG-2'
        assert_equal matchContainer.captures[3],'log_test.rb:114'
        assert_equal matchContainer.captures[4],'This is a test DEBUG-2 message.'
      end
    end

    def test_check_debug_level_3
      #set test phase
      testTime = Time.now
      PARAMS.log_debug_level = 3
      Log.Init #this clears the Log variables and restart the 'flush to file from DB' thread
      Log.logDebug1 'This is a test DEBUG-1 message.'
      Log.logDebug2 'This is a test DEBUG-2 message.'
      Log.logDebug3 'This is a test DEBUG-3 message.'

      #check test phase
      messagesDB = Log.GetMessagesDB
      assert_equal messagesDB.size,4,"At debug level 3, 4 lines (1 header line and 3 debug message) should be found. Test found:#{messagesDB.size} messages"
      #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] [This is a test ERROR message.]
      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'DEBUG-1'
        assert_equal matchContainer.captures[3],'log_test.rb:147'
        assert_equal matchContainer.captures[4],'This is a test DEBUG-1 message.'
      end

      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[2])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'DEBUG-2'
        assert_equal matchContainer.captures[3],'log_test.rb:148'
        assert_equal matchContainer.captures[4],'This is a test DEBUG-2 message.'
      end

      matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[3])  #messagesDB[0] is the init message
      assert_equal matchContainer.captures.size,5
      if matchContainer.captures.size == 5 then
        assert_equal matchContainer.captures[0],'BBFS LOG'
        assert_equal matchContainer.captures[1],testTime.to_s
        assert_equal matchContainer.captures[2],'DEBUG-3'
        assert_equal matchContainer.captures[3],'log_test.rb:149'
        assert_equal matchContainer.captures[4],'This is a test DEBUG-3 message.'
      end
    end
  end
end



