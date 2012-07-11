require 'log'
require 'socket'

module BBFS
  module Networking

    class TCPCallbackReceiver
      def initialize callback, port
        @callback = callback
        @port = port
      end

      def run
        Socket.tcp_server_loop(@port) do |sock, client_addrinfo|
          while size_of_data = sock.read(4)
            size_of_data = size_of_data.unpack("l")[0]
            Log.debug1 "Size of data: #{size_of_data}"
            data = sock.read(size_of_data)
            Log.debug1 "Data received: #{data}"
            unmarshaled_data = Marshal.load(data)
            Log.debug1 "Unmarshaled data: #{unmarshaled_data}"
            @callback.call(unmarshaled_data)
            Log.debug1 "Socket closed? #{sock.closed?}."
            break if sock.closed?
            Log.debug1 'Waiting on sock.read'
          end
          Log.debug1 'Exited, socket closed or read returned nil.'
        end
      end
    end

    class TCPSender
      def initialize host, port
        @host = host
        @port = port
        open_socket
      end

      def open_socket
        Log.debug1 "Connecting to content server #{@host}:#{@port}."
        @tcp_socket = TCPSocket.new(@host, @port)
      end

      def send_content_data content_data
        open_socket if @tcp_socket.closed?
        Log.debug1 "Data to send: #{content_data}"
        marshal_data = Marshal.dump(content_data)
        Log.debug1 "Marshaled size: #{marshal_data.length}."
        data_size = [marshal_data.length].pack("l")
        Log.debug1 "Marshaled data: #{marshal_data}."
        if data_size.nil? || marshal_data.nil?
          Log.debug1 'Send data is nil!'
        end
        @tcp_socket.write data_size
        @tcp_socket.write marshal_data
      end
    end

  end
end
