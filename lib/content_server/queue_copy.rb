require 'thread'

require 'file_indexing/index_agent'
require 'log'
require 'networking/tcp'

module BBFS
  module ContentServer
    Params.integer('ack_timeout', 5, 'Timeout of ack from backup server in seconds.')

    # Copy message types.
    :ACK_MESSAGE
    :COPY_MESSAGE

    # Simple copier, gets inputs events (files to copy), requests ack from backup to copy
    # then copies one file.
    class QueueCopy
      def initialize(copy_input_queue, host, port)
        # Local simple tcp connection.
        @backup_tcp = Networking::TCPClient.new(host, port, method(:receive_ack))
        @copy_input_queue = copy_input_queue
        # Stores for each checksum, the file source path.
        # TODO(kolman): If there are items in copy_prepare which timeout (don't get ack),
        # resend the ack request.
        @copy_prepare = {}
      end

      def receive_ack(message)
        # Add ack message to copy queue.
        Log.info("Ack received: #{message}")
        @copy_input_queue.push(message)
      end

      def run()
        threads = []
        threads << Thread.new do
          while true do
            Log.info 'Waiting on copy files events.'
            message_type, message_content = @copy_input_queue.pop

            if message_type == :COPY_MESSAGE
              Log.info "Copy file event: #{message_content}"
              # Prepare source,dest map for copy.
              message_content.instances.each { |key, instance|
                @copy_prepare[instance.checksum] = instance.full_path
                Log.info("Sending ack for: #{instance.checksum}")
                @backup_tcp.send_obj([:ACK_MESSAGE, [instance.checksum, Time.now.to_i]])
              }
            elsif message_type == :ACK_MESSAGE
              # Received ack from backup, copy file if all is good.
              # The timestamp is of local content server! not backup server!
              timestamp, ack, checksum = message_content

              Log.info("Ack (#{ack}) received for: #{checksum}, timestamp: #{timestamp} " \
                       "now: #{Time.now.to_i}")

              # Copy file if ack (does not exists on backup and not too much time passed)
              if ack && (Time.now.to_i - timestamp < Params['ack_timeout'])
                if !@copy_prepare.key?(checksum)
                  Log.warning("Ack was already received:#{checksum}")
                else
                  file = @copy_prepare[checksum]
                  Log.info "Copying file: #{checksum} #{file}."
                  begin
                    if File.exists?(file)
                      # TODO(kolman): Fails to allocate memory for large files, should send file
                      # as stream.
                      content = File.open(file, 'rb') { |f| f.read() }
                      read_content_checksum = FileIndexing::IndexAgent.get_content_checksum(content)
                      Log.debug1("read_content_checksum: #{read_content_checksum}")
                      if read_content_checksum != checksum
                        Log.error("Read file content is not equal to file checksum.")
                      end
                      # Send pair (content + checksum).
                      Log.debug1("Content to send size: #{content.length}")
                      bytes_written = @backup_tcp.send_obj([:COPY_MESSAGE, [content, checksum]])
                      Log.debug1("Sent content of file #{file}, bytes written: #{bytes_written}.")
                      # We can actually check the number of bytes in content (not in message).
                      if bytes_written > 0
                        @copy_prepare.delete(checksum)
                      else
                        Log.error("Could not copy file, wrote 0 bytes.")
                      end
                    else
                      Log.warning("File to send '#{file}', does not exist")
                    end
                  rescue Errno::EACCES => e
                    Log.warning("Could not open file #{file} for copy. #{e}")
                  end
                end
              end
            else
              Log.error("Copy event not supported: #{message_type}")
            end
          end
        end
      end
    end  # class QueueCopy

    class QueueFileReceiver
      def initialize(port, dynamic_content_data)
        @dynamic_content_data = dynamic_content_data
        @tcp_server = Networking::TCPServer.new(port, method(:on_file_receive))
      end

      def tcp_thread
        return @tcp_server.tcp_thread if @tcp_server != nil
        nil
      end

      # This is a function which receives the messages (file or ack) and return answer in case
      # of ack.
      def on_file_receive(addr_info, message)
        message_type, message_content = message
        if message_type == :COPY_MESSAGE
          content, checksum = message_content
          #Log.info("Content: #{content} class #{content.class}.")
          received_checksum = FileIndexing::IndexAgent.get_content_checksum(content)
          comment = "Calculated received content checksum #{received_checksum}"
          Log.info(comment) if checksum == received_checksum
          Log.error(comment) if checksum != received_checksum

          write_to = QueueFileReceiver.destination_filename(Params['backup_destination_folder'],
                                                            received_checksum)
          if File.exists?(write_to)
            Log.warning("File already exists (#{write_to}) not writing.")
          else
            # Make the directory if does not exists.
            Log.debug1("Writing to: #{write_to}")
            Log.debug1("Creating directory: #{File.dirname(write_to)}")

            FileUtils.makedirs(File.dirname(write_to))
            count = File.open(write_to, 'wb') { |f| f.write(content) }
            Log.debug1("Number of bytes written: #{count}")
            Log.info("File #{write_to} was written.")
          end

          # Check written/local file checksum (maybe skip or send to indexer)
          local_file_checksum = FileIndexing::IndexAgent.get_checksum(write_to)
          message = "Local checksum (#{local_file_checksum}) received checksum #{received_checksum})"
          Log.info(message) ? local_file_checksum == received_checksum : Log.error(message)
        elsif message_type == :ACK_MESSAGE
          checksum, timestamp = message_content
          # Here we should check file existence
          Log.debug1("Returning ack for: #{checksum}, timestamp: #{timestamp}")
          Log.debug1("Ack: #{!@dynamic_content_data.exists?(checksum)}")
          @tcp_server.send_obj([:ACK_MESSAGE, [timestamp,
                                               !@dynamic_content_data.exists?(checksum),
                                               checksum]])
        else
          Log.error("Unexpected message type: #{message_type}")
        end
      end

      # Creates destination filename for backup server, input is base folder and sha1.
      # for example: folder:/mnt/hd1/bbbackup, sha1:d0be2dc421be4fcd0172e5afceea3970e2f3d940
      # dest filename: /mnt/hd1/bbbackup/d0/be/2d/d0be2dc421be4fcd0172e5afceea3970e2f3d940
      def self.destination_filename(folder, sha1)
        File.join(folder, sha1[0,2], sha1[2,2], sha1)
      end

    end # class QueueFileReceiver
  end
end
