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
          p 'Waiting on sock.gets.'
          size_of_data = sock.read(4).unpack("l")[0]
          p "Size of data: #{size_of_data}"
          size_of_data = size_of_data.to_i
          p "Size of data: #{size_of_data}"
          data = sock.read(size_of_data)
          p "Data received: #{data}"
          unmarshaled_data = Marshal.load(data)
          p "Unmarshaled data: #{unmarshaled_data}"
          @queue.push unmarshaled_data
        end
      end
    end

    class ContentDataSender
      def initialize host, port
        p "Connecting to content server #{host}:#{port}."
        @tcp_socket = TCPSocket.open(host, port)
      end

      def send_content_data content_data
        p "Data to send: #{content_data}"
        marshal_data = Marshal.dump(content_data)
        p "Marshaled size: #{marshal_data.length}."
        data_size = [marshal_data.length].pack("l")
        p "Marshaled data: #{marshal_data}."
        @tcp_socket.write data_size
        @tcp_socket.write marshal_data
      end
    end

  end
end
