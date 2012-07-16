require 'log'
require 'rspec'
require 'socket'
require 'stringio'

require_relative '../../lib/networking/tcp'

# Uncomment to debug spec.
BBFS::Params.log_write_to_console = 'true'
BBFS::Params.log_debug_level = 3
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
          tcp_server.server_thread.join
        end

        it 'should connect and receive callback from server' do
          info = 'info'
          data = 'kuku!!!'
          stream = StringIO.new
          ::Socket.stub(:tcp_server_loop).and_yield(stream, info)
          ::TCPSocket.stub(:new).and_return(stream)

          func = lambda { |info, data| Log.info("info, data: #{info}, #{data}") }
          # Check data is received.
          func.should_receive(:call).with(info, data)

          # Send data first.
          tcp_client = TCPClient.new('kuku', 5555, func)
          # Send has to be successful.

          # Note this is very important so that reading the stream from beginning.
          stream.rewind

          tcp_server = TCPServer.new(5555, nil)
          # Wait on server thread.
          sleep(1)
          tcp_server.send_obj(data).should eq({info => true})
          tcp_server.server_thread.join
        end
      end

      describe 'TCPServer' do

      end
    end
  end
end
