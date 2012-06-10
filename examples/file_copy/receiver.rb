# Author: Itzhak B.
# Description: example of using Receiver class (file tcpip_copy.rb)
# Run: ruby -Ilib examples/file_copy/receiver.rb

require_relative '../../lib/file_copy/tcpip_copy.rb'


module BBFS
  module FileCopy
    module Examples
      port = 50152

      queue = Queue.new # creating queue
      rs = Receiver.new port # creating instance of class for server (rs)
      receiver = Thread.new do # creating thread that run the server
        # convey to run method of server the queue in order when new message is received
        # it will be pushed to queue
        rs.run queue
      end

      # when received data from queue pop it from queue and print it to screen
      while value = queue.pop
        puts "consumed #{value}"
      end

      receiver.join
    end
  end
end

