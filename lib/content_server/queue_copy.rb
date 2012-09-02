require 'thread'

require 'content_server/file_streamer'
require 'file_indexing/index_agent'
require 'log'
require 'networking/tcp'

module BBFS
  module ContentServer
    Params.integer('ack_timeout', 5, 'Timeout of ack from backup server in seconds.')

    # Copy message types.
    :ACK_MESSAGE
    :COPY_MESSAGE
    :SEND_COPY_MESSAGE
    :COPY_CHUNK
    :ABORT_COPY

    # Simple copier, gets inputs events (files to copy), requests ack from backup to copy
    # then copies one file.
    class FileCopyServer
      def initialize(copy_input_queue, port)
        # Local simple tcp connection.
        @backup_tcp = Networking::TCPServer.new(port, method(:receive_message))
        @copy_input_queue = copy_input_queue
        # Stores for each checksum, the file source path.
        # TODO(kolman): If there are items in copy_prepare which timeout (don't get ack),
        # resend the ack request.
        @copy_prepare = {}
        @file_streamer = FileStreamer.new(method(:send_chunk))
      end

      def send_chunk(*arg)
        @copy_input_queue.push([:COPY_CHUNK, arg])
      end

      def receive_message(addr_info, message)
        # Add ack message to copy queue.
        Log.info("message received: #{message}")
        @copy_input_queue.push(message)
      end

      def run()
        threads = []
        threads << @backup_tcp.tcp_thread if @backup_tcp != nil
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
                  path = @copy_prepare[checksum]
                  Log.info "Streaming file: #{checksum} #{path}."
                  @file_streamer.start_streaming(checksum, path)
                end
              else
                Log.debug1("Ack timed out span: #{Time.now.to_i - timestamp} > " \
                           "timeout: #{Params['ack_timeout']}")
              end
            elsif message_type == :COPY_CHUNK
              file_checksum, file_size, content, content_checksum = message_content
              Log.info "Send chunk for file #{file_checksum}."
              @backup_tcp.send_obj([:COPY_CHUNK, message_content])
              if content.nil? and content_checksum.nil?
                @copy_prepare.delete(file_checksum)
              end
            elsif message_type == :ABORT_COPY
              Log.info("Aborting file copy: #{message_content}")
              if @copy_prepare.key?(message_content)
                Log.info("Aborting: #{@copy_prepare[message_content]}")
                @copy_prepare.delete(message_content)
              end
              @file_streamer.abort_streaming(message_content)
            else
              Log.error("Copy event not supported: #{message_type}")
            end # handle messages here
          end
          Log.error("Should not reach here, loop should continue.")
        end
      end
    end  # class QueueCopy

    class FileCopyClient
      def initialize(host, port, dynamic_content_data)
        @local_queue = Queue.new
        @dynamic_content_data = dynamic_content_data
        @tcp_server = Networking::TCPClient.new(host, port, method(:handle_message))
        @file_receiver = FileReceiver.new(method(:done_copy), method(:abort_copy))
        @local_thread = Thread.new do
          loop do
            handle(@local_queue.pop)
          end
        end
      end

      def threads
        ret = [@local_thread]
        ret << @tcp_server.tcp_thread if @tcp_server != nil
        return ret
      end

      def request_copy(content_data)
        handle_message([:SEND_COPY_MESSAGE, content_data])
      end

      def abort_copy(checksum)
        handle_message([:ABORT_COPY, checksum])
      end

      def done_copy(local_file_checksum, local_path)
        Log.info("Done copy file: #{local_path}, #{local_file_checksum}")
      end

      def handle_message(message)
        Log.debug2('QueueFileReceiver handle message')
        @local_queue.push(message)
      end

      # This is a function which receives the messages (file or ack) and return answer in case
      # of ack. Note that it is being executed from the class thread only!
      def handle(message)
        message_type, message_content = message
        if message_type == :SEND_COPY_MESSAGE
          Log.debug1("Requesting file (content data) to copy.")
          Log.debug3("File requested: #{message_content.to_s}")
          bytes_written = @tcp_server.send_obj([:COPY_MESSAGE, message_content])
          Log.debug1("Sending copy message succeeded? bytes_written: #{bytes_written}.")
        elsif message_type == :COPY_CHUNK
          @file_receiver.receive_chunk(*message_content)
        elsif message_type == :ACK_MESSAGE
          checksum, timestamp = message_content
          # Here we should check file existence
          Log.debug1("Returning ack for: #{checksum}, timestamp: #{timestamp}")
          Log.debug1("Ack: #{!@dynamic_content_data.exists?(checksum)}")
          @tcp_server.send_obj([:ACK_MESSAGE, [timestamp,
                                               !@dynamic_content_data.exists?(checksum),
                                               checksum]])
        elsif message_type == :ABORT_COPY
          @tcp_server.send_obj([:ABORT_COPY, message_content])
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
