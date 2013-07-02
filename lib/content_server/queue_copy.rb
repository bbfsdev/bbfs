require 'thread'

require 'content_server/file_streamer'
require 'file_indexing/index_agent'
require 'content_server/server'
require 'log'
require 'networking/tcp'
require 'params'


module ContentServer
  Params.integer('ack_timeout', 5, 'Timeout of ack from backup server in seconds.')

  # Copy message types.
  :ACK_MESSAGE
  :COPY_MESSAGE
  :SEND_COPY_MESSAGE
  :COPY_CHUNK
  :COPY_CHUNK_FROM_REMOTE
  :ABORT_COPY # Asks the sender to abort file copy.
  :RESET_RESUME_COPY # Sends the stream sender to resend chunk or resume from different offset.

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
      Log.debug3("initialize FileCopyServer on port:#{port}")
    end

    def send_chunk(*arg)
      @copy_input_queue.push([:COPY_CHUNK, arg])
      $process_vars.set('Copy File Queue Size', @copy_input_queue.size)
    end

    def receive_message(addr_info, message)
      # Add ack message to copy queue.
      Log.debug2("Content server Copy message received: #{message}")
      @copy_input_queue.push(message)
      $process_vars.set('Copy File Queue Size', @copy_input_queue.size)
    end

    def run()
      threads = []
      threads << @backup_tcp.tcp_thread if @backup_tcp != nil
      threads << Thread.new do
        while true do
          Log.debug1 'Waiting on copy files events.'
          message_type, message_content = @copy_input_queue.pop
          $process_vars.set('Copy File Queue Size', @copy_input_queue.size)
          Log.debug1("Content copy message:#{[message_type, message_content]}")
          if message_type == :COPY_MESSAGE
            # Prepare source,dest map for copy.
              message_content.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
                if !@copy_prepare.key?(checksum) || !@copy_prepare[checksum][1]
                  @copy_prepare[checksum] = [path, false]
                  Log.debug1("Sending ack for: #{checksum}")
                  @backup_tcp.send_obj([:ACK_MESSAGE, [checksum, Time.now.to_i]])
                end
              }
            elsif message_type == :ACK_MESSAGE
              # Received ack from backup, copy file if all is good.
              # The timestamp is of local content server! not backup server!
            timestamp, ack, checksum = message_content

            Log.debug1("Ack (#{ack}) received for content: #{checksum}, timestamp: #{timestamp} " \
                       "now: #{Time.now.to_i}")

            # Copy file if ack (does not exists on backup and not too much time passed)
            if ack && (Time.now.to_i - timestamp < Params['ack_timeout'])
              if !@copy_prepare.key?(checksum) || @copy_prepare[checksum][1]
                Log.warning("File was aborted, copied, or started copy just now: #{checksum}")
              else
                path = @copy_prepare[checksum][0]
                Log.info "Streaming to backup server. content: #{checksum} path:#{path}."
                @file_streamer.start_streaming(checksum, path)
                # Ack received, setting prepare to true
                @copy_prepare[checksum][1] = true
              end
            else
              Log.debug1("Ack timed out span: #{Time.now.to_i - timestamp} > " \
                           "timeout: #{Params['ack_timeout']}")
            end
          elsif message_type == :COPY_CHUNK_FROM_REMOTE
            checksum = message_content
            @file_streamer.copy_another_chuck(checksum)
          elsif message_type == :COPY_CHUNK
            # We open the message here for printing info and deleting copy_prepare!
            file_checksum, offset, file_size, content, content_checksum = message_content
            Log.debug1("Send chunk for file #{file_checksum}, offset: #{offset} " \
                         "filesize: #{file_size}.")
            # Blocking send.
            @backup_tcp.send_obj([:COPY_CHUNK, message_content])
            if content.nil? and content_checksum.nil?
              @copy_prepare.delete(file_checksum)
            end
          elsif message_type == :ABORT_COPY
            Log.debug1("Aborting file copy: #{message_content}")
            if @copy_prepare.key?(message_content)
              Log.debug1("Aborting: #{@copy_prepare[message_content][0]}")
              @copy_prepare.delete(message_content)
            end
            @file_streamer.abort_streaming(message_content)
          elsif message_type == :RESET_RESUME_COPY
            file_checksum, new_offset = message_content
            Log.debug1("Resetting/Resuming file (#{file_checksum}) copy to #{new_offset}")
            @file_streamer.reset_streaming(file_checksum, new_offset)
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
      @tcp_client = Networking::TCPClient.new(host, port, method(:handle_message))
      @file_receiver = FileReceiver.new(method(:done_copy),
                                        method(:abort_copy),
                                        method(:reset_copy))
      @local_thread = Thread.new do
        loop do
          pop_data = @local_queue.pop
          $process_vars.set('File Copy Client queue', @local_queue.size)
          handle(pop_data)
        end
      end
      @local_thread.abort_on_exception = true
      Log.debug3("initialize FileCopyClient  host:#{host}  port:#{port}")
    end

    def threads
      ret = [@local_thread]
      ret << @tcp_client.tcp_thread if @tcp_client != nil
      return ret
    end

    def request_copy(content_data)
      handle_message([:SEND_COPY_MESSAGE, content_data])
    end

    def abort_copy(checksum)
      handle_message([:ABORT_COPY, checksum])
    end

    def reset_copy(checksum, new_offset)
      handle_message([:RESET_RESUME_COPY, [checksum, new_offset]])
    end

    def done_copy(local_file_checksum, local_path)
      $process_vars.inc('num_files_received')
      Log.debug1("Done copy file: #{local_path}, #{local_file_checksum}")
    end

    def handle_message(message)
      Log.debug3('QueueFileReceiver handle message')
      @local_queue.push(message)
      $process_vars.set('File Copy Client queue', @local_queue.size)
    end

    # This is a function which receives the messages (file or ack) and return answer in case
    # of ack. Note that it is being executed from the class thread only!
    def handle(message)
      message_type, message_content = message
      Log.debug1("backup copy message: Type #{message_type}")
      Log.debug1("backup copy message: message: #{message_content}")
      if message_type == :SEND_COPY_MESSAGE
        bytes_written = @tcp_client.send_obj([:COPY_MESSAGE, message_content])
        Log.debug2("Sending copy message succeeded? bytes_written: #{bytes_written}.")
      elsif message_type == :COPY_CHUNK
        if @file_receiver.receive_chunk(*message_content)
          file_checksum, offset, file_size, content, content_checksum = message_content
          @tcp_client.send_obj([:COPY_CHUNK_FROM_REMOTE, file_checksum])
        end
      elsif message_type == :ACK_MESSAGE
        checksum, timestamp = message_content
        # Here we should check file existence
        Log.debug1("Returning ack for content: #{checksum}, timestamp: #{timestamp}")
        Log.debug1("Ack: #{!@dynamic_content_data.exists?(checksum)}")
        @tcp_client.send_obj([:ACK_MESSAGE, [timestamp,
                                             !@dynamic_content_data.exists?(checksum),
                                             checksum]])
      elsif message_type == :ABORT_COPY
        @tcp_client.send_obj([:ABORT_COPY, message_content])
      elsif message_type == :RESET_RESUME_COPY
        @tcp_client.send_obj([:RESET_RESUME_COPY, message_content])
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

