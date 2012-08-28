require 'log'
require 'rspec'
require 'socket'
require 'stringio'

require_relative '../../lib/networking/tcp'

# Uncomment to debug spec.
BBFS::Params['log_write_to_console'] = true
BBFS::Params['log_debug_level'] = 0
BBFS::Params['log_param_number_of_mega_bytes_stored_before_flush'] = 0
BBFS::Params['log_param_max_elapsed_time_in_seconds_from_last_flush'] = 0
BBFS::Log.init

module BBFS
  module Networking
    module Spec

      describe 'TCPClient' do
        it 'should warn when destination host+port are bad' do
          data = 'kuku!!!'
          stream = StringIO.new
          stream.close()
          ::TCPSocket.stub(:new).and_return(stream)
          BBFS::Log.should_receive(:warning).with('Socket not opened for writing, skipping send.')

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
        #it 'should connect and receive callback from server' do
        #  info = 'info'
        #  data = 'kuku!!!'
        #  stream = StringIO.new
        #  ::Socket.stub(:tcp_server_loop).once.and_yield(stream, info)
        #  ::TCPSocket.stub(:new).and_return(stream)
        #
        #  tcp_server = nil
        #  new_clb = lambda { |i|
        #    #2 - After after @sockets is filled. Send has to be successful.
        #    tcp_server.send_obj(data).should eq({info => 21})
        #
        #    stream.rewind
        #
        #    func = lambda { |d|
        #      # 6, After client initialized, it should send object.
        #      Log.info("data: #{d}")
        #      # Validate received data.
        #      d.should eq(data)
        #      # Exit tcp client reading loop thread.
        #      Thread.exit
        #    }
        #
        #    # 4 - Create client and wait for read data.
        #    tcp_client = TCPClient.new('kuku', 5555, func)
        #    tcp_client.tcp_thread.abort_on_exception = true
        #    tcp_client.tcp_thread.join()
        #    # We can finish now. Exit tcp server listening loop.
        #    Thread.exit
        #  }
        #  #1 - Create server, send data and wait.
        #  tcp_server = TCPServer.new(5555, nil, new_clb)
        #  tcp_server.tcp_thread.abort_on_exception = true
        #  tcp_server.tcp_thread.join()
        #end
      end
    end
  end
end
