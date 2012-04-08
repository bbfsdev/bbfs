require 'eventmachine'

module BBFS
  module ContentServer

    class ContentDataReceiver
      def initialize queue, host, port
        @queue = queue
        @host = host
        @port = port
      end

      def receive_data(data)
        @queue.push(Marshal.load(data))
      end

      def start_server
        EventMachine::start_server @host, @port, self
        puts "Started ContentDataServer on #{@host}:#{@port}..."
      end
    end

    class ContentDataSender
      def initialize host, port
        @host = host
        @port = port
      end

      def send_content_data content_data
        send_data(Marshal.dump(content_data))
      end

      def connect
        EventMachine.run {
          EventMachine.connect @host, @port, self
        }
      end
    end

  end
end
