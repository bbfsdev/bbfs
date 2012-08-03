require 'params'
require 'log'
require 'networking/nqueue'

BBFS::Params.string('command', 'receiver', 'Either receiver or sender')

BBFS::Params['log_write_to_console'] = true
#BBFS::Params['log_debug_level'] = 3
BBFS::Params.init ARGV
BBFS::Log.init

# This example shows how to use the PQueueSender and Receiver
# Run this file with command receiver first:
# bbfs> ruby -Ilib examples/nqueue_example.rb --command=receiver
# This will execute the receiver queue and open a thread to listen to port 5555
# Now run the sender command, as much times as you want:
# bbfs> ruby -Ilib examples/nqueue_example.rb --command=sender
# Each sender will push the 'Hello World' string to the receiver.

if BBFS::Params['command'] == 'receiver'
  # Receiver
  pq_receiver = BBFS::Networking::NQueue.new(5555)
  count = 0
  loop do
    # Blocking wait
    info, element = pq_receiver.pop_info
    count += 1
    BBFS::Log.info("info:#{info.inspect}, element:#{element}, count:#{count}")
  end
else
  # Sender
  pq_sender = BBFS::Networking::NQueue.new(5555, '127.0.0.1')
  100.times { |i|
    sleep 0.05
    str = "Hello World ##{i}."
    BBFS::Log.info("Sending: '#{str}'")
    pq_sender.push(str)
  }
end
