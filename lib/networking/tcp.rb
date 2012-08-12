require 'log'
require 'socket'

module BBFS
  module Networking

    def Networking.write_to_stream(stream, obj)
      Log.debug3('Writing to stream.')
      marshal_data = Marshal.dump(obj)
      Log.debug1("Writing data size: #{marshal_data.length}")
      data_size = [marshal_data.length].pack("l")
      if data_size.nil? || marshal_data.nil?
        Log.debug3 'Send data size is nil!'
      end
      bytes_written = stream.write data_size
      bytes_written += stream.write marshal_data
      return bytes_written
    end

    # Returns pair [status(true/false), obj]
    def Networking.read_from_stream(stream)
      Log.debug3('Read from stream.')
      return [false, nil] unless size_of_data = stream.read(4)
      size_of_data = size_of_data.unpack("l")[0]
      Log.debug1("Reading data size:#{size_of_data}")
      data = stream.read(size_of_data)
      unmarshalled_data = Marshal.load(data)
      Log.debug3("unmarshalled_data:#{unmarshalled_data}")
      return [true, unmarshalled_data]
    end

    # Limit on number of concurrent connections?
    # The TCP server is not responsible for reconnection.
    class TCPServer
      attr_reader :tcp_thread

      def initialize(port, obj_clb, new_clb=nil, closed_clb=nil, max_parallel=1)
        @port = port
        @obj_clb = obj_clb
        @new_clb = new_clb
        @closed_clb = closed_clb
        # Max parallel connections is not implemented yet.
        @max_parallel = max_parallel
        @sockets = {}
        @tcp_thread = run_server
        @tcp_thread.abort_on_exception = true
        @tcp_client_threads = {}
      end

      def send_obj(obj, addr_info=nil)
        Log.debug3("addr_info=#{addr_info}")
        if addr_info
          Networking.write_to_stream(@sockets[addr_info], obj) > 0
        else
          out = {}
          @sockets.each { |key, sock| out[key] = Networking.write_to_stream(sock, obj) > 0 }
          return out
        end
      end

      private
      # Creates new thread/pool
      def run_server
        Log.debug3('run_server')
        return Thread.new do
          Log.debug3('run_server2')
          Socket.tcp_server_loop(@port) do |sock, addr_info|
            @tcp_client_threads[addr_info] = Thread.new do
              Log.debug3('-----')
              Log.debug3("tcp_server_loop... #{sock} #{addr_info.inspect}")
              @sockets[addr_info] = sock
              @new_clb.call(addr_info) if @new_clb
              loop do
                # Blocking read.
                Log.debug3('read_from_stream')
                status, obj = Networking.read_from_stream(sock)
                Log.debug3("Server returned from read: #{status}, #{obj}")
                @obj_clb.call(addr_info, obj) if @obj_clb && status
                break unless status
              end
              @closed_clb.call(addr_info) if @closed_clb
            end
            @tcp_client_threads[addr_info].abort_on_exception = true
          end
        end
      end
    end  # TCPServer

    class TCPClient
      attr_reader :tcp_thread

      def initialize(host, port, obj_clb=nil, reconnected_clb=nil)
        @host = host
        @port = port
        @tcp_socket = nil
        @obj_clb = obj_clb
        @reconnected_clb = reconnected_clb
        Log.debug1('TCPClient init.')
        Log.debug1("TCPClient init...#{@obj_clb}...")
        if @obj_clb
          @tcp_thread = start_reading
          @tcp_thread.abort_on_exception = true
        end
      end

      def addr_info
        Log.info(@tcp_client.addr.inspect) if @tcp_client
        return @tcp_client.addr if @tcp_client
        return '#{host}:port'
      end

      def send_obj(obj)
        Log.debug1('send_obj')
        open_socket unless socket_good?
        Log.debug1('after open')
        if !socket_good?
          Log.warning('Socket not opened for writing, skipping send.')
          return false
        end
        Log.debug1('writing...')
        bytes_written = Networking.write_to_stream(@tcp_socket, obj)
        return bytes_written > 0
      end

      private
      def open_socket
        Log.debug1("Connecting to content server #{@host}:#{@port}.")
        begin
          @tcp_socket = TCPSocket.new(@host, @port)
        rescue Errno::ECONNREFUSED
          Log.warning('Connection refused')
        end
        Log.debug1("Reconnect clb: '#{@reconnected_clb}'")
        @reconnected_clb.call if @reconnected_clb && socket_good?
      end

      private
      def socket_good?
        Log.debug1 "socket_good? #{@tcp_socket && !@tcp_socket.closed?}"
        return @tcp_socket && !@tcp_socket.closed?
      end

      private
      def start_reading
        Log.debug1('start_reading (TCPClient).')
        return Thread.new do
          loop do
            Log.debug3('Start blocking read (TCPClient).')
            # Blocking read.
            open_socket unless socket_good?
            if !socket_good?
              Log.warning('Socket not good, breaking client reading thread.')
              break
            end
            status, obj = Networking.read_from_stream(@tcp_socket)
            Log.debug3("Client returned from read: #{status}, #{obj}")
            # Handle case when socket is closed in middle.
            # In that case we should not call obj_clb.
            @obj_clb.call(obj) if status
          end
        end
      end
    end  # TCPClient
  end
end
