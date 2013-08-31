require 'log'
require 'rspec'
require 'socket'
require 'stringio'

require_relative '../../lib/networking/tcp'

Log.init

module Networking
  module Spec

    describe 'TCPClient' do
      it 'should warn when destination host+port are bad' do
        data = 'kuku!!!'
        stream = StringIO.new
        stream.close()
        ::TCPSocket.stub(:new).and_return(stream)
        Log.should_receive(:warning).with('Socket not opened for writing, skipping send.')

        # Send data first.
        tcp_client = TCPClient.new('kuku', 5555)
        # Send has to fail.
        tcp_client.send_obj(data).should be(false)
      end

      it 'should send data and server should receive callback function' do
        info = 'info'
        data = 'kuku!!!'
        stream = StringIO.new
        ::Socket.stub(:tcp_server_loop).and_yield(stream, info)
        ::TCPSocket.stub(:new).and_return(stream)

        # Send data first.
        tcp_client = TCPClient.new('kuku', 5555)
        # Send has to be successful.
        tcp_client.send_obj(data).should be(21)

        # Note this is very important so that reading the stream from beginning.
        stream.rewind

        func = lambda { |info, data| Log.info("info, data: #{info}, #{data}") }
        # Check data is received.
        func.should_receive(:call).with(info, data)

        tcp_server = TCPServer.new(5555, func)
        # Wait on server thread.
        tcp_server.tcp_thread.join
      end

      # TODO(kolman): Don't work, missing client send_obj/open_socket execution in
      # the correct place.
      it 'should connect and receive callback from server' do
        info = 'info'
        data = 'kuku!!!'
        stream = StringIO.new
        ::Socket.stub(:tcp_server_loop).once.and_yield(stream, info)
        ::TCPSocket.stub(:new).and_return(stream)

        tcp_server = nil
        new_clb = lambda { |i|
          Log.info("#2 - After after @sockets is filled. Send has to be successful.")
          tcp_server.send_obj(data).should eq({info => 21})

          stream.rewind

          func = lambda { |d|
            Log.info("#6, After client initialized, it should send object.")
            Log.info("data: #{d}")
            # Validate received data.
            d.should eq(data)
            # Exit tcp client reading loop thread.
            Thread.exit
          }

          Log.info("#4 - Create client and wait for read data.")
          tcp_client = TCPClient.new('kuku', 5555, func)
          tcp_client.tcp_thread.abort_on_exception = true
          tcp_client.tcp_thread.join()
          # We can finish now. Exit tcp server listening loop.
          Thread.exit
        }

        Log.info("#1 - Create server, send data and wait.")
        tcp_server = TCPServer.new(5555, nil, new_clb)
        tcp_server.tcp_thread.abort_on_exception = true
        tcp_server.tcp_thread.join()
      end
    end
  end
end

