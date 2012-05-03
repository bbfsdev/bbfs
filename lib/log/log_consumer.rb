require ('thread')
require ('params')

module BBFS
  module Log

    Params.parameter 'log_param_thread_sleep_time_in_seconds', 0.5 , 'log param. Thread sleep time in seconds'
    class Consumer
      def initialize
        @ConsumerQueue = Queue.new
        Thread.new do
          while (true)
            consume @ConsumerQueue.pop
          end
        end
      end

      def pushData data
        @ConsumerQueue.push data.clone
      end
    end

    class BufferConsumerProducer < Consumer
      def initialize bufferSizeInMegaBytes, bufferTimeOutInSeconds
        super()
        @bufferSizeInBytes = bufferSizeInMegaBytes * 1000000
        @bufferTimeOutInSeconds = bufferTimeOutInSeconds
        @timeAtLastFlush = Time.now.to_i
        @buffer = []
        @consumers = []
        Thread.new do
          while (true)
            if @ConsumerQueue.empty? then
              @ConsumerQueue.push nil
              sleep Params.log_param_thread_sleep_time_in_seconds
            end
          end
        end

      end

      #flush the DB to the consumers
      def flushToConsumers
        @consumers.each { |consumer| consumer.pushData @buffer}
        @buffer.clear
        @timeAtLastFlush = Time.now.to_i
      end

      def consume data
        @buffer.push data if not data.nil?
        if (@buffer.inspect.size > @bufferSizeInBytes) or
            ((Time.now.to_i -  @timeAtLastFlush) >= @bufferTimeOutInSeconds) then
          flushToConsumers
        end
      end

      def addConsumer consumer
        @consumers.push consumer
      end
    end

    class ConsoleConsumer < Consumer
      def consume data
        puts data
      end
    end

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
          fileHandler = File.new @file_name, 'a'
          fileHandler.puts data
        rescue
          Exception
          puts "Failed to open log file:#{@file_name}"
          puts $!.class
          puts $!
        ensure
          fileHandler.close
        end
      end
    end
  end
end
