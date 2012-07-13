require 'log'
require 'socket'

module BBFS
  module Networking

    def write_to_stream(stream, obj)
      marshal_data = Marshal.dump(obj)
      data_size = [marshal_data.length].pack("l")
      if data_size.nil? || marshal_data.nil?
        Log.debug1 'Send data size is nil!'
      end
      bytes_written = sock.write data_size
      bytes_written += sock.write marshal_data
    end

    def read_from_stream(stream)
      size_of_data = stream.read(4)
      return nil unless size_of_data
      size_of_data = size_of_data.unpack("l")[0]
      data = stream.read(size_of_data)
      unmarshalled_data = Marshal.load(data)
      return unmarshalled_data
    end

    # Limit on number of concurrent connections?
    # The TCP server is not responsible for reconnection.
    class TCPServer
      def initialize(port, obj_clb, new_clb=nil, closed_clb=nil, max_parallel=1)
        @port = port
        @obj_clb = obj_clb
        @new_clb = new_clb
        @closed_clb = closed_clb
        # Max parallel connections is not implemented yet.
        @max_parallel = max_parallel
        @sockets = {}
        run_server
      end

      def send(obj, addr_info=nil)
        if addr_info
          write_to_stream(@sockets[addr_info], obj)
        else
          @sockets.values.each { |sock| write_to_stream(sock, obj) }
        end
      end

      private
      # Creates new thread/pool
      def run_server
        Thread.new do
          Socket.tcp_server_loop(@port) do |sock, addr_info|
            @sockets[addr_info] = sock
            @new_clb.call(addr_info)
            loop do
              # Blocking read.
              obj = read_from_stream(sock)
              @obj_clb.call(addr_info, obj)
            end
          end
        end
      end
    end  # TCPServer

    class TCPClient
      def initialize(host, port, obj_clb=nil, reconnected_clb=nil)
        @host = host
        @port = port
        @tcp_socket = nil
        @obj_clb = obj_clb
        @reconnected_clb = reconnected_clb
        run_server unless @obj_clb
      end

      def open_socket
        Log.debug1 "Connecting to content server #{@host}:#{@port}."
        @tcp_socket = TCPSocket.new(@host, @port)
        @reconnected_clb.call if @reconnected_clb && socket_good?
      end

      def socket_good?
        return @tcp_socket && !@tcp_socket.closed?
      end

      def send_data obj
        open_socket unless socket_good?
        if !socket_good?
          Log.warning('Socket not opened for writing, skipping send.')
          return false
        end
        bytes_written = write_to_stream(@socket, obj)
        return bytes_written > 0
      end

      private
      def run_server
        Thread.new do
          loop do
            # Blocking read.
            open_socket unless socket_good?
            obj = read_from_stream(@tcp_socket)
            # Handle case when socket is closed in middle.
            # In that case we should not call obj_clb.
            @obj_clb.call(obj)
          end
        end
      end
    end  # TCPClient

  end
end
