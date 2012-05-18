require File.dirname(__FILE__) + '/tcpip_copy.rb'

port = 50152

h = Sender.new "localhost", port
h2 = Sender.new "localhost", port
h2.send("hello from host 2")
h2.close
h.send("hello")
h.send("world")
h.send_file(File.dirname(__FILE__) + '/sender/file_to_send.txt')

h.close

