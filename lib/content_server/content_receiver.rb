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
            p "Size of data: #{size_of_data}"
            data = sock.read(size_of_data)
            p "Data received: #{data}"
            unmarshaled_data = Marshal.load(data)
            p "Unmarshaled data: #{unmarshaled_data}"
            @queue.push unmarshaled_data
            p "Socket closed? #{sock.closed?}."
            break if sock.closed?
            p 'Waiting on sock.read'
          end
          p 'Exited, socket closed or read returned nil.'
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
        p "Connecting to content server #{@host}:#{@port}."
        @tcp_socket = TCPSocket.new(@host, @port)
      end

      def send_content_data content_data
        open_socket if @tcp_socket.closed?
        p "Data to send: #{content_data}"
        marshal_data = Marshal.dump(content_data)
        p "Marshaled size: #{marshal_data.length}."
        data_size = [marshal_data.length].pack("l")
        p "Marshaled data: #{marshal_data}."
        if data_size.nil? || marshal_data.nil?
          p 'Send data is nil!!!!!!!!'
        end
        @tcp_socket.write data_size
        @tcp_socket.write marshal_data
      end
    end

  end
end
