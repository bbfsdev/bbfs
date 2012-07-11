require 'log'
require 'rspec'
require 'socket'

require_relative '../../lib/networking/tcp'

BBFS::Params.log_write_to_console = 'true'
BBFS::Log.init

module BBFS
  module Networking
    module Spec

      describe 'TCPCallbackReceiver' do
        it 'should get data and call callback' do
          stream = StringIO.new()
          data = 'kuku!!!'
          ::Socket.stub(:tcp_server_loop).and_yield(stream, nil)
          ::TCPSocket.stub(:new).and_return(stream)

          BBFS::Log.debug1('kukukukukuku')

          func = lambda { |data| print data }.should_receive(:call).with(data)
          tcp_receiver = TCPCallbackReceiver.new(func, 5555)
          tcp_receiver.run()

          tcp_sender = TCPSender.new('kuku', 5555)
          tcp_sender.send_content_data(data)
        end

      end
    end
  end
end
