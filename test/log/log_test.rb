# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: Log test file.
# run: rake test.
# Note: This file will be tested along with all project tests.

require ('params')
require 'test/unit'
require_relative '../../lib/log.rb'
require_relative '../../lib/log/log_consumer.rb'

module BBFS

  module Log
    # Creating a test consumer class to be able to read the data pushed
    # to the consumer by the logger
    class TestConsumer < Consumer

      def initialize
        super
        @data_list = []
      end

      def consume data
        @data_list.push data
      end

      def get_data_list
          return @data_list
      end
      def init
        @data_list.clear
      end
    end

    class TestLog < Test::Unit::TestCase

      def initialize name
        super
        @test_consumer = TestConsumer.new
        Log.clear
        Log.add_consumer @test_consumer
      end

      def test_check_info_format
        #set test phase
        testTime = Time.now
        Log.info 'This is a test INFO message.'
        line = __LINE__ - 1
        sleep 0.1
        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 1, \
          "1 line should be found. Test found:#{messages.size}"
        #check expected format: [BBFS LOG] [Time] [INFO] [log_test.rb:11]
        # [This is a test INFO message.]
        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[0])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'INFO'
          assert_equal format_containers.captures[3], "log_test.rb:#{line}"
          assert_equal format_containers.captures[4], 'This is a test INFO message.'
        end
      end

      def test_check_warning_format
        #set test phase
        testTime = Time.now
        Log.warning 'This is a test WARNING message.'
        line = __LINE__ - 1
        sleep 0.1

        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 1, "1 line should be found. Test found:#{messages.size}"
        #check expected format: [BBFS LOG] [Time] [WARNING] [log_test.rb:35] \
        # [This is a test WARNING message.]
        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[0])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'WARNING'
          assert_equal format_containers.captures[3], "log_test.rb:#{line}"
          assert_equal format_containers.captures[4], 'This is a test WARNING message.'
        end
      end

      def test_check_error_format
        #set test phase
        testTime = Time.now
        Log.error 'This is a test ERROR message.'
        line = __LINE__ - 1
        sleep 0.1

        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 1, "1 line should be found. Test found:#{messages.size}"
        #check expected format: [BBFS LOG] [Time] [ERROR] [log_test.rb:35] \
        # [This is a test ERROR message.]
        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[0])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'ERROR'
          assert_equal format_containers.captures[3], "log_test.rb:#{line}"
          assert_equal format_containers.captures[4], 'This is a test ERROR message.'
        end
      end

      def test_check_debug_level_0
        #set test phase
        Params.log_debug_level = 0
        #@test_consumer = TestConsumer.new
        #Log.add_consumer @test_consumer
        Log.debug1 'This is a test debug-1 message.'
        Log.debug2 'This is a test debug-2 message.'
        Log.debug3 'This is a test debug-3 message.'
        sleep 0.1

        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 0 , \
          "At debug level 0, no debug messages should be found.Test found:#{messages.size} messages."
      end

      def test_check_debug_level_1
        #set test phase
        testTime = Time.now
        Params.log_debug_level = 1
        #@test_consumer = TestConsumer.new
        #Log.add_consumer @test_consumer
        Log.debug1 'This is a test DEBUG-1 message.'
        line = __LINE__ - 1
        Log.debug2 'This is a test DEBUG-2 message.'
        Log.debug3 'This is a test DEBUG-3 message.'
        sleep 0.1

        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 1, \
          "At debug level 1, 1 line should be found. Test found:#{messages.size} messages."
        #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] \
        # [This is a test ERROR message.]
        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[0])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'DEBUG-1'
          assert_equal format_containers.captures[3],"log_test.rb:#{line}"
          assert_equal format_containers.captures[4], 'This is a test DEBUG-1 message.'
        end
      end

      def test_check_debug_level_2
        #set test phase
        testTime = Time.now
        Params.log_debug_level = 2
        #@test_consumer = TestConsumer.new
        #Log.add_consumer @test_consumer
        Log.debug1 'This is a test DEBUG-1 message.'
        line1 = __LINE__ - 1
        Log.debug2 'This is a test DEBUG-2 message.'
        line2 = __LINE__ - 1
        Log.debug3 'This is a test DEBUG-3 message.'
        sleep 0.1

        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 2, \
          "At debug level 2, 2 lines should be found. Test found:#{messages.size} messages."
        #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] \
        # [This is a test ERROR message.]
        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[0])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'DEBUG-1'
          assert_equal format_containers.captures[3], "log_test.rb:#{line1}"
          assert_equal format_containers.captures[4], 'This is a test DEBUG-1 message.'
        end

        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[1])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'DEBUG-2'
          assert_equal format_containers.captures[3], "log_test.rb:#{line2}"
          assert_equal format_containers.captures[4], 'This is a test DEBUG-2 message.'
        end
      end

      def test_check_debug_level_3
        #set test phase
        testTime = Time.now
        Params.log_debug_level = 3
        #@test_consumer = TestConsumer.new
        #Log.add_consumer @test_consumer
        Log.debug1 'This is a test DEBUG-1 message.'
        line1 = __LINE__ - 1
        Log.debug2 'This is a test DEBUG-2 message.'
        line2 = __LINE__ - 1
        Log.debug3 'This is a test DEBUG-3 message.'
        line3 = __LINE__ - 1
        sleep 0.1

        #check test phase
        messages = @test_consumer.get_data_list
        assert_equal messages.size, 3, \
          "At debug level 3, 3 lines should be found. Test found:#{messages.size} messages."
        #check expected format: [BBFS LOG] [Time] [DEBUG-1] [log_test.rb:35] \
        # [This is a test ERROR message.]
        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[0])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'DEBUG-1'
          assert_equal format_containers.captures[3], "log_test.rb:#{line1}"
          assert_equal format_containers.captures[4], 'This is a test DEBUG-1 message.'
        end

        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[1])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'DEBUG-2'
          assert_equal format_containers.captures[3], "log_test.rb:#{line2}"
          assert_equal format_containers.captures[4], 'This is a test DEBUG-2 message.'
        end

        format_containers = /\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\]/.match(messages[2])
        assert_equal format_containers.captures.size, 5
        if format_containers.captures.size == 5 then
          assert_equal format_containers.captures[0], 'BBFS LOG'
          assert_equal format_containers.captures[1], testTime.to_s
          assert_equal format_containers.captures[2], 'DEBUG-3'
          assert_equal format_containers.captures[3], "log_test.rb:#{line3}"
          assert_equal format_containers.captures[4], 'This is a test DEBUG-3 message.'
        end
      end
    end
  end
end



