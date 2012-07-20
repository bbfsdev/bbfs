# Author: Itzhak B.
# Description: copy data and files by tcpip protocol
# Run: ruby -Ilib examples/file_copy/receiver.rb, ruby -Ilib examples/file_copy/sender.rb

# TODO add spec

require 'socket'
require 'thread'

require 'log'

module BBFS
  module FileCopy
    # host that send data and files(using file names)
    class Sender
      # name - initialize
      # inputs: addr -address of server, port_num - port of server
      # description: initialize class Sender and open socket to server
      def initialize(addr, port_num)
        @LOG = Log
        @socket = TCPSocket.open addr, port_num
        addr = @socket.addr
        addr.shift  # removes "AF_INET"
        @LOG.debug3("socket open on addr: #{addr.join(":")}")
        peer_addr = @socket.peeraddr
        peer_addr.shift  # removes "AF_INET"
        @LOG.info("connected to peer: #{peer_addr.join(":")}")
      end

      # name - send
      # inputs: data - any type of data, classes expect from instances of class IO,
      #                or singleton objects
      # description: marshaling received data and send it through socket
      def send(data)
        @LOG.debug3("data to send is (#{data}).")
        marshal_data = Marshal.dump(data)
        data_size = [marshal_data.length].pack("l")
        @socket.write(data_size)
        @socket.write(marshal_data)
      end

      # name - send_file
      # inputs: file_name - name of file (string)
      # description: send data readed from file
      # TODO need to think if to remove this method
      def send_file(file_name)
        #check if source file is exist
        if (File.exists?(file_name) == false)
          # TODO (itzhak) check why warning is not written
          @LOG.warning("source file '#{file_name} ' Does not exist")
          return -1
        end

        file = File.open(file_name, "r")
        content = file.read
        send(content)
      end

      # name - close
      # description: close the socket to server
      def close
        @socket.close
      end
    end

    # multiclient server that receive data
    class Receiver
      # name - initialize
      # inputs: addr port_num - port to accept connections
      # description: initialize class Receiver and open socket to server
      def initialize(port_num)
        @LOG = Log
        @port_num = port_num
        @server = TCPServer.open 'localhost', port_num
        addr = @server.addr
        addr.shift            # removes "AF_INET"
        @LOG.info("server is on #{addr.join(":")}")
      end

      # name - run
      # inputs: queue - received data pushed to queue
      # description: 1) Listening on port for connections
      #              2) When connections opened received the marshaled data
      #              3) Load marshaled data and push it to queue
      def run(queue)
        loop do
          @LOG.debug1 "waiting on #{@port_num}"
          Thread.start(@server.accept) do |client|
            addr = client.addr
            addr.shift  # removes "AF_INET"
            @LOG.debug1("accept connection addr: #{addr.join(":")}")
            peer_addr = client.peeraddr
            peer_addr.shift  # removes "AF_INET"
            @LOG.info("connected to peer: #{peer_addr.join(":")}")
            while size = client.recv(4).unpack("l")[0]
              @LOG.debug3 "begin receiving data with size #{size}"
              data = client.recv(size)
              unmarshaled_data = Marshal.load(data)
              @LOG.debug3 "data received (#{unmarshaled_data})"
              queue.push unmarshaled_data
            end
            @LOG.info "connection #{peer_addr.join(":")} is closed by other side"
          end # Thread.start(@server.accept) do |client|
        end # loop do
      end # def run
    end # class Receiver
  end # module FileCopy
end  # module BBFS
