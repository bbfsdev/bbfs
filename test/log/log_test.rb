# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: Log test file.
# run: rake test.
# Note: This file will be tested along with all project tests.

require 'params'
require 'test/unit'
require_relative '../../lib/log.rb'
require_relative '../../lib/log/log_consumer.rb'

  module Log
    # Creating a test consumer class to be able to read the data pushed
    # to the consumer by the logger
    class TestConsumer < Consumer
      attr_reader :test_queue

      def initialize
        super
        @test_queue = Queue.new()
      end

      def consume data
        @test_queue.push data
      end
    end

    class TestLog < Test::Unit::TestCase

      LOG_TEST_FILE_NAME = 'log_test.rb:'
      LOG_PREFIX = 'BBFS LOG'

      def initialize name
        super
        Params['log_write_to_console'] = false
        Params['log_write_to_file'] = false
        Log.init
        @test_consumer = TestConsumer.new
        Log.add_consumer @test_consumer
        @line_regexp = Regexp.new(/\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/)
      end

      #check expected format: [LOG_PREFIX] [Time] [INFO] [FILE_NAME:LINE] [MESSAGE]
      def assert_message line, time, type, file_line, msg
        format_containers = @line_regexp.match(line)
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], LOG_PREFIX
          assert_equal format_containers.captures[1], time.to_s
          assert_equal format_containers.captures[2], type
          assert_equal format_containers.captures[3], file_line
          assert_equal format_containers.captures[4], msg
        end
      end

      def test_check_info_format
        #set test phase
        test_message = 'This is a test INFO message.'
        testTime = Time.now
        Log.info test_message
        line = __LINE__ - 1
        #check test phase
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'INFO', LOG_TEST_FILE_NAME + line.to_s, test_message
      end

      def test_check_warning_format
        #set test phase
        test_message = 'This is a test WARNING message.'
        testTime = Time.now
        Log.warning test_message
        line = __LINE__ - 1

        #check test phase
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'WARNING', LOG_TEST_FILE_NAME + line.to_s, test_message
      end

      def test_check_error_format
        #set test phase
        test_message = 'This is a test ERROR message.'
        testTime = Time.now
        Log.error test_message
        line = __LINE__ - 1

        #check test phase
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'ERROR', LOG_TEST_FILE_NAME + line.to_s, test_message
      end

      def test_check_debug_level_0
        #set test phase
        Params['log_debug_level'] = 0
        Log.debug1 'This is a test debug-1 message.'
        Log.debug2 'This is a test debug-2 message.'
        Log.debug3 'This is a test debug-3 message.'
        #check test phase
        queue_size = @test_consumer.test_queue.size
        assert_equal queue_size, 0 , \
          "At debug level 0, no debug messages should be found.Test found:#{queue_size} messages."
      end

      def test_check_debug_level_1
        #set test phase
        Params['log_debug_level'] = 1
        test_message_1 = 'This is a test DEBUG-1 message.'
        test_message_2 = 'This is a test DEBUG-2 message.'
        test_message_3 = 'This is a test DEBUG-3 message.'
        testTime = Time.now
        Log.debug1 test_message_1
        line = __LINE__ - 1
        Log.debug2 test_message_2
        Log.debug3 test_message_3

        #check test phase
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'DEBUG-1', LOG_TEST_FILE_NAME + line.to_s, test_message_1
      end

      def test_check_debug_level_2
        #set test phase
        Params['log_debug_level'] = 2
        test_message_1 = 'This is a test DEBUG-1 message.'
        test_message_2 = 'This is a test DEBUG-2 message.'
        test_message_3 = 'This is a test DEBUG-3 message.'
        testTime = Time.now
        Log.debug1 test_message_1
        line_1 = __LINE__ - 1
        Log.debug2 test_message_2
        line_2 = __LINE__ - 1
        Log.debug3 test_message_3

        #check test phase
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'DEBUG-1', LOG_TEST_FILE_NAME + line_1.to_s, test_message_1
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'DEBUG-2', LOG_TEST_FILE_NAME + line_2.to_s, test_message_2
      end

      def test_check_debug_level_3
        #set test phase
        Params['log_debug_level'] = 3
        test_message_1 = 'This is a test DEBUG-1 message.'
        test_message_2 = 'This is a test DEBUG-2 message.'
        test_message_3 = 'This is a test DEBUG-3 message.'
        testTime = Time.now
        Log.debug1 'This is a test DEBUG-1 message.'
        line_1 = __LINE__ - 1
        Log.debug2 'This is a test DEBUG-2 message.'
        line_2 = __LINE__ - 1
        Log.debug3 'This is a test DEBUG-3 message.'
        line_3 = __LINE__ - 1

        #check test phase
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'DEBUG-1', LOG_TEST_FILE_NAME + line_1.to_s, test_message_1
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'DEBUG-2', LOG_TEST_FILE_NAME + line_2.to_s, test_message_2
        pop_message = @test_consumer.test_queue.pop
        assert_message pop_message, testTime, 'DEBUG-3', LOG_TEST_FILE_NAME + line_3.to_s, test_message_3
      end
    end
end
