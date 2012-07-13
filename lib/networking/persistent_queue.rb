require 'log'

require 'networking/tcp'

module BBFS
  module Networking

    class PQueueSender < Queue
      def initialize(remote_host, remote_port, local_port)
        super()
        @tcp_sender = TCPSender.new(remote_host, remote_port)
        @tcp_receiver = TCPCallbackReceiver.new(method(:register), local_port)
        @tcp_receiver.run
      end

      def register(queue_names)

      end

      def push(obj)
        @tcp_sender.send_data(obj)
      end

      def pop(non_block=false)
        raise 'Wrong usage'
      end
    end

    class PQueueReceiver < Queue
      def initialize(port, listening_queue_names=[])
        super()
        @tcp_receiver = TCPCallbackReceiver.new(method(:push), port)
        @tcp_receiver.run
      end
    end

  end
end

