require 'socket'

module BBFS
  module ContentServer

    class ContentDataReceiver
      def initialize queue, port
        @queue = queue
        @port = port
      end

      def run
        Socket.tcp_server_loop(@port) do |sock, client_addrinfo|
          while size_of_data = sock.read(4)
            size_of_data = size_of_data.unpack("l")[0]
            Log.info "Size of data: #{size_of_data}"
            data = sock.read(size_of_data)
            Log.info "Data received: #{data}"
            unmarshaled_data = Marshal.load(data)
            Log.info "Unmarshaled data: #{unmarshaled_data}"
            @queue.push unmarshaled_data
            Log.info "Socket closed? #{sock.closed?}."
            break if sock.closed?
            Log.info 'Waiting on sock.read'
          end
          Log.info 'Exited, socket closed or read returned nil.'
        end
      end
    end

    class ContentDataSender

      def initialize host, port
        @host = host
        @port = port
        open_socket
      end

      def open_socket
        Log.info "Connecting to content server #{@host}:#{@port}."
        @tcp_socket = TCPSocket.new(@host, @port)
      end

      def send_content_data content_data
        open_socket if @tcp_socket.closed?
        Log.info "Data to send: #{content_data}"
        marshal_data = Marshal.dump(content_data)
        Log.info "Marshaled size: #{marshal_data.length}."
        data_size = [marshal_data.length].pack("l")
        Log.info "Marshaled data: #{marshal_data}."
        if data_size.nil? || marshal_data.nil?
          Log.info 'Send data is nil!!!!!!!!'
        end
        @tcp_socket.write data_size
        @tcp_socket.write marshal_data
      end
    end

  end
end
