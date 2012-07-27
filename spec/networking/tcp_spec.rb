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
          tcp_client.send_obj(data).should be(true)

          # Note this is very important so that reading the stream from beginning.
          stream.rewind

          func = lambda { |info, data| Log.info("info, data: #{info}, #{data}") }
          # Check data is received.
          func.should_receive(:call).with(info, data)

          tcp_server = TCPServer.new(5555, func)
          # Wait on server thread.
          tcp_server.tcp_thread.join
         end

        it 'should connect and receive callback from server' do
          info = 'info'
          data = 'kuku!!!'
          stream = StringIO.new
          ::Socket.stub(:tcp_server_loop).once.and_yield(stream, info)
          ::TCPSocket.stub(:new).and_return(stream)

          tcp_server = TCPServer.new(5555, nil)
          # Wait for @sockets to be filled.
          sleep 0.1
          # Send has to be successful.
          tcp_server.send_obj(data).should eq({info => true})
          stream.rewind

          func = lambda { |d| Log.info("data: #{d}") }
          # Check data is received.
          func.should_receive(:call).with(data)
          # Send data first.
          tcp_client = TCPClient.new('kuku', 5555, func)

          # Wait for the read loop to read the stream at least once.
          sleep 0.1
        end
      end
    end
  end
end
