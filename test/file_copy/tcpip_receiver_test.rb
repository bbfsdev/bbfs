# Author: Itzhak B.
# Description: Test for Sender and Receiver class of FileCopy module (file tcpip_copy.rb)
# Run: ruby -Ilib test/file_copy/tcpip_receiver_test.rb
require 'test/unit'

require_relative '../../lib/file_copy/tcpip_copy'

LOCAL_PATH = File.dirname(__FILE__)
FILE_NAME = File.join(LOCAL_PATH, '/test_files/file_to_send.txt')

module BBFS
  module FileCopy
    module Test
      class TcpipReceiverTest < ::Test::Unit::TestCase
        PORT = 50152 # port number for Receiver(server) and Sender(client)

        @queue    = nil # queue used by server
        @receiver = nil # handler of thread for receiver
        @host     = nil # handler of sender 1
        @host2    = nil # handler of sender 2

        def setup
          Thread.abort_on_exception = true

          # create server (receiver)
          @queue = Queue.new
          rs = Receiver.new PORT

          @receiver = Thread.new do
            rs.run @queue
          end

          # create host (sender)
          @host = Sender.new "localhost", PORT
        end

        def test_send_file

          ############ TEST 1 (test send_file)#################
          # send content of FILE_NAME (by sender)
          @host.send_file(FILE_NAME)

          # read content of FILE_NAME
          file = File.open(FILE_NAME, "r")
          content = file.read

          # get from server file that send by host
          value = @queue.pop
          # equal between send and read data
          assert_equal(content, value)

          ############ TEST 2 (test send)#################
          data = "hahaha let's check you"
          @host.send(data)

          value = @queue.pop
          assert_equal(data, value)

          ############ TEST 3 (test when two or more sockets open)#################
          @host2 = Sender.new "localhost", PORT

          data2 = "the second host send data"
          @host2.send(data2)

          value = @queue.pop
          assert_equal(data2, value)

          data = "the first sender send this data"
          @host.send(data)

          value = @queue.pop
          assert_equal(data, value)

          # close socket
          @host.close

          data2 = "the second part of data after host 1 was closed"
          @host2.send(data2)

          value = @queue.pop
          assert_equal(data2, value)

          ################ TEST 4 what happened when receiver fail during open socket #########
          # TODO not working
          # kill thread that run server
          Thread.kill(@receiver)
          sleep(2)

          @host2.send(data2)

          @host2.close

          value2 = @queue.pop
          assert_equal(data2, value2)
        end
      end
    end
  end
end
