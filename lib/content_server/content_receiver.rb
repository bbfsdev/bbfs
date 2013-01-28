require 'log'
require 'params'
require 'socket'

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
          Log.debug3 "Size of data: #{size_of_data}"
          data = sock.read(size_of_data)
          #Log.debug3 "Data received: #{data}"
          unmarshaled_data = Marshal.load(data)
          #Log.debug3 "Unmarshaled data: #{unmarshaled_data}"
          @queue.push unmarshaled_data
          Log.debug3 "Socket closed? #{sock.closed?}."
          break if sock.closed?
          Log.debug1 'Waiting on sock.read'
        end
        Log.debug1 'Exited, socket closed or read returned nil.'
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
      Log.debug1 "Connecting to content server #{@host}:#{@port}."
      @tcp_socket = TCPSocket.new(@host, @port)
    end

    def send_content_data content_data
      open_socket if @tcp_socket.closed?
      #Log.debug3 "Data to send: #{content_data}"
      marshal_data = Marshal.dump(content_data)
      Log.debug3 "Marshaled size: #{marshal_data.length}."
      data_size = [marshal_data.length].pack("l")
      #Log.debug3 "Marshaled data: #{marshal_data}."
      if data_size.nil? || marshal_data.nil?
        Log.debug3 'Send data is nil!!!!!!!!'
      end
      @tcp_socket.write data_size
      @tcp_socket.write marshal_data
    end
  end

end

