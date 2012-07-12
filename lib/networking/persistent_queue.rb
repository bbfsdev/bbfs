require 'log'

require 'networking/tcp'

module BBFS
  module Networking

    class PQueueSender < Queue
      def initialize(host, port)
        @tcp_sender = TCPSender.new(host, port)
      end

      def push(obj)
        @tcp_sender.send_data(obj)
      end

      def pop(non_block=false)
        raise 'Wrong usage'
      end
    end

    class PQueueReceiver < Queue
      def initialize(port)
        super
        @tcp_receiver = TCPCallbackReceiver.new(method(:push), port)
      end
    end

  end
end

