# This example shows bi-directional simple communication between TCP server and client.
# Example run:
# bbfs>ruby -Ilib examples/tcp_example.rb --log_debug_level=3
require 'log'
require 'networking/tcp'
require 'params'

Params['log_write_to_console'] = true
Params['log_debug_level'] = 0

Params.init ARGV

Log.init

def server_receive_obj(addr_info, hello_msg)
  Log.info('Got from client: %s' % hello_msg)
  Log.debug1(addr_info.inspect)
end

def client_receive_obj(hello_msg)
  Log.info('Got from server: %s' % hello_msg)
  $tcp_client.send_obj('Hello again.')
end

Log.info('Creating TCP client and server.')
$tcp_server = Networking::TCPServer.new(5555, method(:server_receive_obj))
# Wait for server to start server loop.
sleep 0.1
$tcp_client = Networking::TCPClient.new('localhost', 5555, method(:client_receive_obj))
# Wait for client to start reading thread.
sleep 0.1

Log.info('Sending hello...')
Log.info("send from client:#{$tcp_client.send_obj('Hello from client.')}")
Log.info("send from server:#{$tcp_server.send_obj('Hello from server.')}")

Log.info('Waiting on threads.')
# Wait for all threads (don't exit).
$tcp_server.tcp_thread.join
$tcp_client.tcp_thread.join
Log.info('Should not get here.')
