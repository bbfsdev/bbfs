require 'log'

require 'networking/tcp'

module BBFS
  module Networking

    class PQueueSender < Queue
      def initialize(remote_host, remote_port)
        super()
        @tcp_client = Networking::TCPClient.new(remote_host, remote_port, method(:push))
      end

      def push(obj)
        @tcp_client.send_obj(obj)
      end

      def pop(non_block=false)
        raise 'Wrong usage'
      end
    end

    class PQueueReceiver < Queue
      def initialize(port, listening_queue_names=[])
        super()
        @tcp_server = Networking::TCPServer.new(port, method(:receive_obj))
      end

      def receive_obj(info, obj)
        push(obj)
      end
    end
  end
end

