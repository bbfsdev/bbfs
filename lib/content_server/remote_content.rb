require 'thread'

require 'content_data/dynamic_content_data'
require 'log'
require 'networking/tcp'
require 'params'

module ContentServer

  Params.integer('remote_content_fetch_timeout', 10, 'Remote content desired freshness in seconds.')
  Params.integer('remote_content_save_timeout', 60*60, 'Remote content force refresh in seconds.')

  # TODO(kolman): Use only one tcp/ip socket by utilizing one NQueue for many queues!
  class RemoteContentClient
    def initialize(dynamic_content_data, host, port, local_backup_folder)
      @dynamic_content_data = dynamic_content_data
      @remote_tcp = Networking::TCPClient.new(host, port, method(:receive_content))
      @last_fetch_timestamp = nil
      @last_save_timestamp = nil
      @content_server_content_data_path = File.join(local_backup_folder, 'remote',
                                                    host + '_' + port.to_s)
      Log.debug3("Initialized RemoteContentClient: host:#{host}   port:#{port}  local_backup_folder:#{local_backup_folder}")
    end

    def receive_content(message)
      Log.debug1("Backup server received Remote content data:#{message.to_s}")
      Log.info("Backup server received Remote content data")
      ref = @dynamic_content_data.last_content_data
      @dynamic_content_data.update(message)
      @last_fetch_timestamp = Time.now.to_i

      save_time_span = Params['remote_content_save_timeout']
      if !@last_save_timestamp.nil?
        save_time_span = Time.now.to_i - @last_save_timestamp
      end

      if save_time_span >= Params['remote_content_save_timeout']
      	@last_save_timestamp = Time.now.to_i
        write_to = File.join(@content_server_content_data_path,
                             @last_save_timestamp.to_s + '.cd')
        FileUtils.makedirs(@content_server_content_data_path) unless \
              File.directory?(@content_server_content_data_path)
        count = File.open(write_to, 'wb') { |f| f.write(message.to_s) }
        Log.debug1("Written content data to file:#{write_to}.")
      else
        Log.debug1("No need to write remote content data, it has not changed.")
      end
    end

    def run()
      Log.debug1("Running remote content client.")
      threads = []
      threads << @remote_tcp.tcp_thread if @remote_tcp != nil
      threads << Thread.new do
        Log.debug1("New thread.")
        loop do
          # if need content data
          sleep_time_span = Params['remote_content_save_timeout']
          if !@last_fetch_timestamp.nil?
            sleep_time_span = Time.now.to_i - @last_fetch_timestamp
          end
          Log.debug1("sleep_time_span: #{sleep_time_span}")
          if sleep_time_span >= Params['remote_content_save_timeout']
            # Send ping!
            bytes_written = @remote_tcp.send_obj(nil)
            Log.info("sending ping request for remote content data!")
          end
          sleep(sleep_time_span) if sleep_time_span > 0
        end
      end
    end
  end

  class RemoteContentServer
    def initialize(dynamic_content_data, port)
      @dynamic_content_data = dynamic_content_data
      @tcp_server = Networking::TCPServer.new(port, method(:content_requested))
      Log.debug3("initialize RemoteContentServer on port:#{port}")
    end

    def content_requested(addr_info, message)
      # Send response.
      Log.info("Content server received content data request")
      Log.debug1("Sending content data:#{@dynamic_content_data.last_content_data}")
      @tcp_server.send_obj(@dynamic_content_data.last_content_data)
      Log.info('Content server sent content data')
    end

    def tcp_thread
      return @tcp_server.tcp_thread if @tcp_server != nil
      nil
    end

  end

end

