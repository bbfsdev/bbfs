require File.dirname(__FILE__) + '/tcpip_copy.rb'
#require File.dirname(__FILE__) + '/mylogger.rb'

queue = Queue.new
port = 50152

Thread.abort_on_exception = true

queue = Queue.new
rs = Receiver.new port

receiver = Thread.new do
  rs.run queue
end


while value = queue.pop
  puts "consumed #{value}"
end

receiver.join