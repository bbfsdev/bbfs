require 'thread'

require 'file_indexing/index_agent'
require 'log'
require 'networking/tcp'

module BBFS
  module ContentServer
    Params.integer('ack_timeout', 5, 'Timeout of ack from backup server in seconds.')

    # Simple copier, gets inputs events (files to copy), requests ack from backup to copy
    # then copies one file.
    class QueueCopy
      def initialize(copy_input_queue, host, port)
        # Local simple tcp connection.
        @backup_tcp = Networking::TCPClient.new(host, port, method(:copy_acked_file))
        @copy_input_queue = copy_input_queue
        @copy_ack_queue = Queue.new
      end

      def copy_acked_file(addr_info, message)
        # The timestamp is of local content server! not backup server!
        timestamp, ack, checksum = message

        # Copy file if ack (does not exists on backup and not too much time passed)
        if time() - timestamp < ack_timeout && ack

        end
      end

      def run()
        threads = []
        threads << Thread.new do
          while true do
            Log.info 'Waiting on copy files events.'
            copy_event = @copy_input_queue.pop

            Log.info "Copy file event: #{copy_event}"

            # Prepare source,dest map for copy.
            used_contents = Set.new
            files_map = Hash.new
            Log.info "Instances: #{copy_event.instances}"
            copy_event.instances.each { |key, instance|
              Log.info "Instance: #{instance}"
              # Add instance only if such content has not added yet.
              if !used_contents.member?(instance.checksum)
                files_map[instance.full_path] = instance.checksum
                used_contents.add(instance.checksum)
              end
            }

            Log.info "Copying files: #{files_map}."
            # Copy files, waits until files are finished copying.
            uploads = files_map.map { |file, checksum|
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
                  bytes_written = @backup_tcp.send_obj([content, checksum])
                  Log.debug1("Sent content of file #{file}, bytes written: #{bytes_written}.")
                else
                  Log.warning("File to send '#{file}', does not exist")
                end
              rescue Errno::EACCES => e
                Log.warning("Could not open file #{file} for copy. #{e}")
              end
            }
          end
        end

      end

    end  # class QueueCopy
  end
end
