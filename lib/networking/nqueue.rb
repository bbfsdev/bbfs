require 'log'

require 'networking/tcp'

module BBFS
  module Networking

    # NQueue is bi-directional queue which transfers object using network (tcp/ip).
    # The queue has two working modes:
    # a) As TCP client - when initialized with remote port + host.
    # b) As TCP server - when initialized with port only.
    # In both cases after the TCP connection is esteblished the user can push objects to the queue
    # and pop objects from it which comes from the other side.
    # The qeueu interface and behaiviour is the same as basic Queue.
    class NQueue < Queue
      def initialize(port, host=nil)
        super()
        @tcp_server = Networking::TCPServer.new(port, method(:receive_server_obj)) unless host
        @tcp_client = Networking::TCPClient.new(host, port,
                                                method(:receive_client_obj)) if host
      end

      # We need to alias Queue.push method to call it from receive_server_obj and
      # receive_client_obj.
      alias :base_push :push

      # Send object to the remote computer.
      def push(obj)
        @tcp_client.send_obj(obj) if @tcp_client
        @tcp_server.send_obj(obj) if @tcp_server
      end

      # Object have been received from tcp server, push it to the queue.
      def receive_server_obj(info, obj)
        base_push([info, obj])
      end

      # Object have been received from tcp client, push it to the queue.
      def receive_client_obj(obj)
        base_push([@tcp_client.addr_info, obj])
      end

      # We need to alias Queue.pop method to call it from pop_info.
      alias :base_pop :pop
      # Returns object pushed into queue from remote computer.
      def pop(non_block=false)
        info, obj = super(non_block)
        return obj
      end

      # Returns pair info, obj.
      def pop_info(non_block=false)
        return base_pop(non_block)
      end

    end
  end
end

