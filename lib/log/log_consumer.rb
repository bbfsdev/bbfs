# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: Implementation of the Log module - consumer\producer library.
# Note: The library could be enhance in the future due to project requirement (such as logging
# to mail, archives, remote servers etc)

require 'thread'
require 'params'

module BBFS

  module Log
    Params.float 'log_param_thread_sleep_time_in_seconds', 0.5 , \
    'log param. Thread sleep time in seconds'

    # Base class for all consumers
    # Child consumers must implement the 'consume' virtual method
    class Consumer
      # Initializes the consumer queue and starts a thread. The thread waits for data
      # on the queue, and when data is popped, activates the virtual 'consume' method.
      def initialize
        @consumer_queue = Queue.new
        # TODO(slava): Add bool flag
        Thread.new do
          while (true)
            consume @consumer_queue.pop
          end
        end
      end

      # push incoming data to the consumer queue
      def push_data data
        @consumer_queue.push data.clone
      end
    end

    # BufferConsumerProducer acts as a consumer and as a producer.
    # It has it's own consumers which are added to it.
    # It saves all the data it consumes in a buffer which has a size and time limits.
    # When one of the limits is exceeded, it flushes the buffer to it's own consumers
    class BufferConsumerProducer < Consumer
      def initialize buffer_size_in_mega_bytes, buffer_time_out_in_seconds
        super()
        @buffer_size_in_bytes = buffer_size_in_mega_bytes * 1000000
        @buffer_time_out_in_seconds = buffer_time_out_in_seconds
        @time_at_last_flush = Time.now.to_i
        @buffer = []
        @consumers = []
        Thread.new do
          while (true)
            if @consumer_queue.empty? then
              @consumer_queue.push nil
              sleep Params['log_param_thread_sleep_time_in_seconds']
            end
          end
        end
      end

      def add_consumer consumer
        @consumers.push consumer
      end

      def consume data
        @buffer.push data if not data.nil?
        if (@buffer.inspect.size >= @buffer_size_in_bytes) or
            ((Time.now.to_i - @time_at_last_flush) >= @buffer_time_out_in_seconds) then
          flush_to_consumers
        end
      end

      # flush the DB to the consumers
      def flush_to_consumers
        @consumers.each { |consumer| consumer.push_data @buffer}
        @buffer.clear
        @time_at_last_flush = Time.now.to_i
      end
    end

    # The console consumer logs the data to the standard output
    class ConsoleConsumer < Consumer
      def consume data
        puts data
      end
    end

    # The file consumer logs the data to a file
    class FileConsumer < Consumer
      def initialize file_name
        super()
        @file_name = file_name
        if File.exist? @file_name then
          File.delete @file_name
        end
      end

      def consume data
        begin
          file_handler = File.new @file_name, 'a'
          file_handler.puts data
        rescue
          Exception
          puts "Failed to open log file:#{@file_name}"
          puts $!.class
          puts $!
        ensure
          file_handler.close
        end
      end
    end
  end
end
