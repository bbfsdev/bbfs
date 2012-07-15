require 'log'
require 'socket'

module BBFS
  module Networking

    def Networking.write_to_stream(stream, obj)
      Log.debug1('Writing to stream.')
      marshal_data = Marshal.dump(obj)
      Log.debug1("Writing data size: #{marshal_data.length}")
      data_size = [marshal_data.length].pack("l")
      if data_size.nil? || marshal_data.nil?
        Log.debug1 'Send data size is nil!'
      end
      bytes_written = stream.write data_size
      bytes_written += stream.write marshal_data
    end

    # Returns pair [status(true/false), obj]
    def Networking.read_from_stream(stream)
      Log.debug1('Read from stream.')
      return [false, nil] unless size_of_data = stream.read(4)
      size_of_data = size_of_data.unpack("l")[0]
      Log.debug1("size_of_data:#{size_of_data}")
      data = stream.read(size_of_data)
      unmarshalled_data = Marshal.load(data)
      Log.debug1("unmarshalled_data:#{unmarshalled_data}")
      return [true, unmarshalled_data]
    end

    # Limit on number of concurrent connections?
    # The TCP server is not responsible for reconnection.
    class TCPServer
      attr_reader :server_thread

      def initialize(port, obj_clb, new_clb=nil, closed_clb=nil, max_parallel=1)
        @port = port
        @obj_clb = obj_clb
        @new_clb = new_clb
        @closed_clb = closed_clb
        # Max parallel connections is not implemented yet.
        @max_parallel = max_parallel
        @sockets = {}
        @server_thread = run_server
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
        Log.debug1('run_server')
        Thread.new do
          Log.debug1('run_server2')
          Socket.tcp_server_loop(@port) do |sock, addr_info|
            Log.debug1('tcp_server_loop ' + sock.string + ' ' + addr_info)
            @sockets[addr_info] = sock
            Log.debug1('tcp_server_loop')
            @new_clb.call(addr_info) if @new_clb
            loop do
              # Blocking read.
              Log.debug1('read_from_stream')
              status, obj = Networking.read_from_stream(sock)
              Log.debug1("Returned from read: #{status}, #{obj}")
              @obj_clb.call(addr_info, obj) if @obj_clb && status
              break unless status
            end
            @closed_clb.call(addr_info) if @closed_clb
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
        run_server if @obj_clb
      end

      def send obj
        open_socket unless socket_good?
        if !socket_good?
          Log.warning('Socket not opened for writing, skipping send.')
          return false
        end
        bytes_written = Networking.write_to_stream(@tcp_socket, obj)
        return bytes_written > 0
      end

      private
      def open_socket
        Log.debug1 "Connecting to content server #{@host}:#{@port}."
        @tcp_socket = TCPSocket.new(@host, @port)
        @reconnected_clb.call if @reconnected_clb && socket_good?
      end

      private
      def socket_good?
        return @tcp_socket && !@tcp_socket.closed?
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
