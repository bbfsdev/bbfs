require 'log'
require 'networking/tcp'

BBFS::Params.log_write_to_console = 'true'
BBFS::Params.log_debug_level = 3
BBFS::Log.init

def server_receive_obj(hello_msg)
  puts hello_msg
end

def client_receive_obj(hello_msg)
  puts hello_msg
  $tcp_client.send_obj('Hello back.')
end

puts 'Creating TCP server and client.'
$tcp_server = BBFS::Networking::TCPServer.new(5555, method(:server_receive_obj))
$tcp_client = BBFS::Networking::TCPClient.new('localhost', 5555, method(:client_receive_obj))

puts 'Waiting 1 sec for connection.'
# Wait for the connection to be established
sleep 1

puts 'Sending hello...'
$tcp_client.send_obj('Hello clients.')

puts 'Waiting on threads.'
# Wait for all threads (don't exit).
$tcp_client.tcp_thread.join
$tcp_server.tcp_thread.join
puts 'Should not get here.'