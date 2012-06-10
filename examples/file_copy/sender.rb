# Author: Itzhak B.
# Description: example of using Sender class (file tcpip_copy.rb)
# Run: ruby -Ilib examples/file_copy/sender.rb
require_relative '../../lib/file_copy/tcpip_copy.rb'

# TODO (itzhak and yaron) check why log file is not created

module BBFS
  module FileCopy
    module Examples
      # prepare constatnts and variables
      port = 50152
      # Helper variable: directory of current example file!
      LOCAL_PATH = File.dirname(__FILE__)
      # Directory of example files.
      FILES_DIR = File.join(LOCAL_PATH, '/files_to_send/file_to_send.txt')

      puts "#{FILES_DIR}"

      # create two clients (h and h2)
      h = Sender.new "localhost", port
      h2 = Sender.new "localhost", port

      # send from client 2 and close connection
      h2.send("hello from host 2")
      h2.close

      # send from client 1 and close connection
      h.send("hello")
      h.send("world")
      # TODO (itzhak) check why the file is not sent
      h.send_file(FILES_DIR)

      h.close
    end
  end
end
