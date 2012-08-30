require 'log'
require 'socket'

module BBFS
  module Networking

    Params.integer('client_retry_delay', 60, 'Number of seconds before trying to reconnect.')

    # TODO(kolman): To get robustness, just use try catch + return 0 bytes on write +
    # return false on status on read.
    def Networking.write_to_stream(stream, obj)
      Log.debug3('Writing to stream.')
      marshal_data = Marshal.dump(obj)
      Log.debug2("Writing data size: #{marshal_data.length}")
      data_size = [marshal_data.length].pack("l")
      if data_size.nil? || marshal_data.nil?
        Log.debug3 'Send data size is nil!'
      end
      begin
        bytes_written = stream.write data_size
        bytes_written += stream.write marshal_data
        return bytes_written
      rescue Exception => e
        Log.warning("Could not write tcp/ip stream, #{e.to_s}")
        begin
          stream.close()
        rescue IOError => e
          Log.warning("Could not close stream, #{e.to_s}.")
        end
        return 0
      end
    end

    # Returns pair [status(true/false), obj]
    def Networking.read_from_stream(stream)
      Log.debug3('Read from stream.')
      begin
        return [false, nil] unless size_of_data = stream.read(4)
        size_of_data = size_of_data.unpack("l")[0]
        Log.debug2("Reading data size:#{size_of_data}")
        data = stream.read(size_of_data)
      rescue Exception => e
        Log.warning("Could not read tcp/ip stream, #{e.to_s}.")
        begin
          stream.close()
        rescue IOError => e
          Log.warning("Could not close stream, #{e.to_s}.")
        end
        return [false, nil]
      end

      unmarshalled_data = Marshal.load(data)
      Log.debug3('Read good.')
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
      end

      def send_obj(obj, addr_info=nil)
        Log.debug3("addr_info=#{addr_info}")
        unless addr_info.nil?
          if @sockets.key?(addr_info)
            Networking.write_to_stream(@sockets[addr_info], obj)
          else
            Log.warning("Could not find client socket: #{addr_info}")
            return 0
          end
        else
          out = {}
          @sockets.each { |key, sock| out[key] = Networking.write_to_stream(sock, obj) }
          return out
        end
      end

      private
      # Creates new thread/pool
      def run_server
        Log.debug3('run_server')
        return Thread.new do
          Log.debug3('run_server2')
          loop {
            begin
              Socket.tcp_server_loop(@port) do |sock, addr_info|
                Log.debug3("----- #{@port} -----")
                Log.debug3("tcp_server_loop... #{sock} #{addr_info.inspect}")
                @sockets[addr_info] = sock
                @new_clb.call(addr_info) if @new_clb != nil
                loop do
                  # Blocking read.
                  Log.debug3('read_from_stream')
                  stream_ok, obj = Networking.read_from_stream(sock)
                  Log.debug3("Server returned from read: #{stream_ok}")
                  @obj_clb.call(addr_info, obj) if @obj_clb != nil && stream_ok
                  break if !stream_ok
                end
                Log.warning("Connection broken, #{addr_info.inspect}")
                begin
                  @sockets[addr_info].close() unless @sockets[addr_info].nil?
                rescue IOError => e
                  Log.warning("Could not close socket, #{e.to_s}.")
                end
                @sockets.delete(addr_info)
                @closed_clb.call(addr_info) if @closed_clb != nil
              end
            break # !!! note this break is needed for tests only !!!! server loop should never end.
            rescue IOError => e
              Log.info("Connection broken during tcp_server_loop. Restarting server loop " \
                       "port:#{port}.")
            end
          }
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
        if @obj_clb != nil
          @tcp_thread = start_reading
          @tcp_thread.abort_on_exception = true
        end
        # Variable to signal when remote server is ready.
        @remote_server_available = ConditionVariable.new
        @remote_server_available_mutex = Mutex.new
        open_socket unless socket_good?
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
        #Log.debug3("socket port: #{@tcp_socket.peeraddr}")
        bytes_written = Networking.write_to_stream(@tcp_socket, obj)
        return bytes_written
      end

      # This function may be executed only from one thread!!! or in synchronized manner.
      # private
      def open_socket
        Log.debug1("Connecting to content server #{@host}:#{@port}.")
        begin
          @tcp_socket = TCPSocket.new(@host, @port)
        rescue Errno::ECONNREFUSED
          Log.warning('Connection refused')
        end
        Log.debug1("Reconnect clb: '#{@reconnected_clb.nil? ? 'nil' : @reconnected_clb}'")
        if socket_good?
          @remote_server_available_mutex.synchronize {
            @remote_server_available.signal
          }
          @reconnected_clb.call if @reconnected_clb != nil && socket_good?
        end
      end

      private
      def socket_good?
        Log.debug1 "socket_good? #{@tcp_socket != nil && !@tcp_socket.closed?}"
        return @tcp_socket != nil && !@tcp_socket.closed?
      end

      private
      def start_reading
        Log.debug1('start_reading (TCPClient).')
        return Thread.new do
          loop do
            Log.debug3('Start blocking read (TCPClient).')
            # Blocking read.
            if !socket_good?
              Log.warning("Socket not good, waiting for reconnection with " \
                          "#{Params['client_retry_delay']} seconds timeout.")
              @remote_server_available_mutex.synchronize {
                @remote_server_available.wait(@remote_server_available_mutex,
                                              Params['client_retry_delay'])
              }
            else
              read_ok, obj = Networking.read_from_stream(@tcp_socket)
              Log.debug3("Client returned from read: #{read_ok}")
              # Handle case when socket is closed in middle.
              # In that case we should not call obj_clb.
              @obj_clb.call(obj) if (read_ok && @obj_clb != nil)
            end
          end
        end
      end
    end  # TCPClient
  end
end
