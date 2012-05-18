require 'test/unit'

require_relative '../../lib/file_copy/tcpip_copy'

FILE_NAME = File.dirname(__FILE__) + '/test_files/file_to_send.txt'

module BBFS
  module FileCopy
    module Test
      class TcpipReceiverTest < ::Test::Unit::TestCase
        def test_receiver
          queue = Queue.new
          port = 50152
          
          Thread.abort_on_exception = true
          
          # create server (receiver) 
          queue = Queue.new
          rs = Receiver.new port
          
          receiver = Thread.new do
            rs.run queue
          end
          
          # create host (sender)
          h = Sender.new "localhost", port
          
          ############ TEST 1 (test send_file)#################
          #send content of FILE_NAME (by sender)
          h.send_file(FILE_NAME)         
          
          # read content of FILE_NAME
          file = File.open(FILE_NAME, "r")  
          content = file.read
                    
          # get from server file that send by host 
          value = queue.pop
          #equal between send and read data
          assert_equal(content, value)
          
          ############ TEST 2 (test send)#################
          data = "hahaha let's check you"
          h.send(data)
          
          value = queue.pop
          assert_equal(data, value)          
          
          ############ TEST 3 (test when two or more sockets open)#################
          h2 = Sender.new "localhost", port
          
          data2 = "the second host send data"          
          h2.send(data2)
          
          value = queue.pop
          assert_equal(data2, value)
          
          data = "the first sender send this data"
          h.send(data)
          
          value = queue.pop
          assert_equal(data, value)
          
          #close socket 
          h.close
          
          data2 = "the second part of data after host 1 was closed"          
          h2.send(data2)
          
          value = queue.pop
          assert_equal(data2, value)
          
          h2.close
          
          #kill thread that run server
          Thread.kill(receiver)          
        end
      end
    end
  end
end
