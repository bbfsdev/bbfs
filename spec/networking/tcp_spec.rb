require 'log'
require 'rspec'
require 'socket'
require 'stringio'

require_relative '../../lib/networking/tcp'

# Uncomment to debug spec.
#BBFS::Params.log_write_to_console = 'true'
#BBFS::Params.log_debug_level = 3
#BBFS::Log.init

module BBFS
  module Networking
    module Spec

      describe 'TCPSend' do
        it 'should warn when destination host+port are bad' do
          data = 'kuku!!!'
          stream = StringIO.new
          stream.close()
          ::TCPSocket.stub(:new).and_return(stream)
          BBFS::Log.should_receive(:warning).with('Socket not opened for writing, skipping send.')

          # Send data first.
          tcp_sender = TCPSender.new('kuku', 5555)
          # Send has to fail.
          tcp_sender.send_content_data(data).should be(false)
        end
      end

      describe 'TCPCallbackReceiver' do
        it 'should get data and call callback function' do
          data = 'kuku!!!'
          stream = StringIO.new
          ::Socket.stub(:tcp_server_loop).and_yield(stream, nil)
          ::TCPSocket.stub(:new).and_return(stream)

          # Send data first.
          tcp_sender = TCPSender.new('kuku', 5555)
          # Send has to be successful.
          tcp_sender.send_content_data(data).should be(true)

          # Note this is very important so that reading the stream from beginning.
          stream.rewind

          func = lambda {|data| print data}
          # Check data is received.
          func.should_receive(:call).with(data)

          tcp_receiver = TCPCallbackReceiver.new(func, 5555)
          tcp_receiver.run()
        end

      end
    end
  end
end
