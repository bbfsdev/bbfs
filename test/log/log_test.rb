
require ('params')
require 'test/unit'
require_relative '../../lib/log.rb'
require_relative '../../lib/log/log_consumer.rb'

module BBFS
  module Log

    class TestConsumer < Consumer

      def initialize
        super
        @dataList = []
        @semaphore = Mutex.new
      end

      def consume data
        @semaphore.synchronize{
          @dataList.push data
        }
      end

      def getDataList
        @semaphore.synchronize{
          return @dataList
        }
      end
      def init
        @semaphore.synchronize{
          @dataList.clear
        }
      end
    end

    class TestLog < Test::Unit::TestCase

      Params.log_write_to_file = false
      Params.log_write_to_console = false

      def test_check_info_format
        #set test phase
        Log.init
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        testTime = Time.now
        Log.logInfo 'This is a test INFO message.'
        line = __LINE__ - 1
        sleep 0.1
        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,1,"1 line should be found. Test found:#{messagesDB.size}"
        #check expected format: [BBFS LOG] [Time] [INFO] [log_test.rb:11] [This is a test INFO message.]
        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[0])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'INFO'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line}"
          assert_equal matchContainer.captures[4],'This is a test INFO message.'
        end
      end

      def test_check_warning_format
        #Params.log_file_name = File.expand_path 'log_test_out_dir/log_test.txt'

        #set test phase
        Log.init
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        testTime = Time.now
        Log.logWarning 'This is a test WARNING message.'
        line = __LINE__ - 1
        sleep 0.1

        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,1,"1 line should be found. Test found:#{messagesDB.size}"
        #check expected format: [BBFS LOG] [Time] [WARNING] [log_test.rb:35] [This is a test WARNING message.]
        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[0])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'WARNING'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line}"
          assert_equal matchContainer.captures[4],'This is a test WARNING message.'
        end
      end

      def test_check_error_format

        #set test phase
        Log.init
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        testTime = Time.now
        Log.logError 'This is a test ERROR message.'
        line = __LINE__ - 1
        sleep 0.1

        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,1,"1 line should be found. Test found:#{messagesDB.size}"
        #check expected format: [BBFS LOG] [Time] [ERROR] [log_test.rb:35] [This is a test ERROR message.]
        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[0])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'ERROR'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line}"
          assert_equal matchContainer.captures[4],'This is a test ERROR message.'
        end
      end

      def test_check_debug_level_0
        #set test phase
        Log.init
        Params.log_debug_level = 0
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        Log.logDebug1 'This is a test debug-1 message.'
        Log.logDebug2 'This is a test debug-2 message.'
        Log.logDebug3 'This is a test debug-3 message.'
        sleep 0.1

        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,0,"At debug level 0, no debug messages should be found.Test found:#{messagesDB.size} messages."
      end

      def test_check_debug_level_1
        #set test phase
        Log.init
        testTime = Time.now
        Params.log_debug_level = 1
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        Log.logDebug1 'This is a test DEBUG-1 message.'
        line = __LINE__ - 1
        Log.logDebug2 'This is a test DEBUG-2 message.'
        Log.logDebug3 'This is a test DEBUG-3 message.'
        sleep 0.1

        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,1,"At debug level 1, 1 line should be found. Test found:#{messagesDB.size} messages."
        #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] [This is a test ERROR message.]
        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[0])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'DEBUG-1'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line}"
          assert_equal matchContainer.captures[4],'This is a test DEBUG-1 message.'
        end
      end

      def test_check_debug_level_2
        #set test phase
        Log.init
        testTime = Time.now
        Params.log_debug_level = 2
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        Log.logDebug1 'This is a test DEBUG-1 message.'
        line1 = __LINE__ - 1
        Log.logDebug2 'This is a test DEBUG-2 message.'
        line2 = __LINE__ - 1
        Log.logDebug3 'This is a test DEBUG-3 message.'
        sleep 0.1

        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,2,"At debug level 2, 2 lines should be found. Test found:#{messagesDB.size} messages."
        #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] [This is a test ERROR message.]
        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[0])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'DEBUG-1'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line1}"
          assert_equal matchContainer.captures[4],'This is a test DEBUG-1 message.'
        end

        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'DEBUG-2'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line2}"
          assert_equal matchContainer.captures[4],'This is a test DEBUG-2 message.'
        end
      end

      def test_check_debug_level_3
        #set test phase
        Log.init
        testTime = Time.now
        Params.log_debug_level = 3
        testConsumer = TestConsumer.new
        Log.addConsumer testConsumer
        Log.logDebug1 'This is a test DEBUG-1 message.'
        line1 = __LINE__ - 1
        Log.logDebug2 'This is a test DEBUG-2 message.'
        line2 = __LINE__ - 1
        Log.logDebug3 'This is a test DEBUG-3 message.'
        line3 = __LINE__ - 1
        sleep 0.1

        #check test phase
        messagesDB = testConsumer.getDataList
        assert_equal messagesDB.size,3,"At debug level 3, 3 lines should be found. Test found:#{messagesDB.size} messages."
        #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] [This is a test ERROR message.]
        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[0])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'DEBUG-1'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line1}"
          assert_equal matchContainer.captures[4],'This is a test DEBUG-1 message.'
        end

        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[1])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'DEBUG-2'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line2}"
          assert_equal matchContainer.captures[4],'This is a test DEBUG-2 message.'
        end

        matchContainer = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messagesDB[2])  #messagesDB[0] is the init message
        assert_equal matchContainer.captures.size,5
        if matchContainer.captures.size == 5 then
          assert_equal matchContainer.captures[0],'BBFS LOG'
          assert_equal matchContainer.captures[1],testTime.to_s
          assert_equal matchContainer.captures[2],'DEBUG-3'
          assert_equal matchContainer.captures[3],"log_test.rb:#{line3}"
          assert_equal matchContainer.captures[4],'This is a test DEBUG-3 message.'
        end
      end
    end
  end
end



