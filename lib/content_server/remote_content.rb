require 'thread'

require 'content_data/dynamic_content_data'
require 'log'
require 'networking/tcp'
require 'params'

module ContentServer

  Params.integer('remote_content_fetch_timeout', 10, 'Remote content desired freshness in seconds.')
  Params.integer('remote_content_save_timeout', 60*60, 'Remote content force refresh in seconds.')

# Remote content Client
  # Remote Content (client) - Periodically requests remote content (content server) from Remote Content Server.
  # Stores locally the remote content data structure.
  # Remote content client protocol based on time.
  # Each n seconds it requests content from Remote Content Client connects to server (tcp/ip) and waits for request.
  # remote_content_save_timeout is pre defined in config-backup_server.yml
  class RemoteContentClient
    # initializes class variables
    # @param dynamic_content_data [dynamic_content_data]
    # @param host [ host] host address
    # @param port[ port]  port TCP/IP port
    # @param local_backup_folder [local_backup_folder] pre defined folder for backup
    def initialize(host, port, local_backup_folder)
      @remote_tcp = Networking::TCPClient.new(host, port, method(:receive_content))
      @last_fetch_timestamp = nil
      @last_save_timestamp = nil
      @last_content_data_id = nil
      @content_server_content_data_path = File.join(local_backup_folder, 'remote',
                                                    host + '_' + port.to_s)
      Log.debug3("Initialized RemoteContentClient: host:#{host}   port:#{port}  local_backup_folder:#{local_backup_folder}")
    end

    # Receives content data,  and writes it to file
    # Unchanged data will not be saved
    # @param message [Message] ContentData object
    def receive_content(message)
      Log.info("Backup server received Remote content data")
      @last_fetch_timestamp = Time.now.to_i

      # Update remote content data and write to file if changed ContentData received
      if(message.unique_id != @last_content_data_id)
        path = File.join(@content_server_content_data_path, @last_save_timestamp.to_s + '.cd')
        FileUtils.makedirs(@content_server_content_data_path) unless \
              File.directory?(@content_server_content_data_path)
        $remote_content_data_lock.synchronize{
          $remote_content_data = message
          $remote_content_data.to_file(path)
          @last_content_data_id = message.unique_id   # save last content data ID
        }
        Log.debug1("Written content data to file:#{path}.")
      else
        Log.debug1("No need to write remote content data, it has not changed.")
      end
    end

    # Runs Remote content client
    def run()
      Log.debug1("Running remote content client.")
      threads = []
      threads << @remote_tcp.tcp_thread if @remote_tcp != nil
      threads << Thread.new do
        Log.debug1("New thread.")
        loop do
          # if need content data
          sleep_time_span = Params['remote_content_save_timeout']
          if @last_fetch_timestamp
            sleep_time_span = Time.now.to_i - @last_fetch_timestamp
          end
          Log.debug1("sleep_time_span: #{sleep_time_span}")
          if sleep_time_span >= Params['remote_content_save_timeout']
            # Send ping!
            @remote_tcp.send_obj(nil)
            Log.info("sending ping request for remote content data!")
          end
          sleep(sleep_time_span) if sleep_time_span > 0
        end
      end
    end
  end

# Remote Content Server
   # Simple TCP server.
   #It connects to server and listens to incoming requests. After receiving the request it sends local content data structure.
  class RemoteContentServer
    # initializes class variables
    # @param dynamic_content_data [dynamic_content_data] Content data
    # @param port [dynamic_content_data] TCP/IP port
    def initialize(port)
      @tcp_server = Networking::TCPServer.new(port, method(:content_requested))
      Log.debug3("initialize RemoteContentServer on port:#{port}")
    end

    # content_requested
    # @param addr_info [addr_info] address information
    # @param message [message] Content Data
    def content_requested(addr_info, message)
      # Send response.
      Log.info("Content server received content data request")
      $local_content_data_lock.synchronize{
        Log.debug1("Sending content data:#{$local_content_data}")
        @tcp_server.send_obj($local_content_data)
      }
      Log.info('Content server sent content data')
    end

    # Open TCP/IP Thread
    # @return [run_server] (see #run_server)run TCP server definition in tcp.rb
    def tcp_thread
      return @tcp_server.tcp_thread if @tcp_server != nil
      nil
    end

  end

end

