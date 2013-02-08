require 'thread'

require 'content_data/dynamic_content_data'
require 'log'
require 'networking/tcp'
require 'params'

module ContentServer

  Params.integer('remote_content_timeout', 10, 'Remote content desired freshness in seconds.')
  Params.integer('max_content_timeout', 60*60, 'Remote content force refresh in seconds.')

  # TODO(kolman): Use only one tcp/ip socket by utilizing one NQueue for many queues!
  class RemoteContent
    def initialize(dynamic_content_data, host, port, local_backup_folder)
      @dynamic_content_data = dynamic_content_data
      @remote_tcp = Networking::TCPClient.new(host, port, method(:receive_content))
      @last_update_timestamp = nil
      @content_server_content_data_path = File.join(local_backup_folder, 'remote',
                                                    host + '_' + port.to_s)
    end

    def receive_content(message)
      Log.debug1("Remote content data received: #{message.to_s}")
      ref = @dynamic_content_data.last_content_data
      @dynamic_content_data.update(message)

      max_time_span = Params['max_content_timeout']
      if !@last_update_timestamp.nil?
        max_time_span = Time.now.to_i - @last_update_timestamp
      end

      @last_update_timestamp = Time.now.to_i

      if ref != message || max_time_span >= Params['max_content_timeout']
        Log.debug2("Remote content data changed or max time span is large, writing.")
        Log.debug3("max_time_span: #{max_time_span}")
        write_to = File.join(@content_server_content_data_path,
                             @last_update_timestamp.to_s + '.cd')
        FileUtils.makedirs(@content_server_content_data_path) unless \
              File.directory?(@content_server_content_data_path)
        count = File.open(write_to, 'wb') { |f| f.write(message.to_s) }
      else
        Log.debug2("No need to write remote content data, it has not changed.")
      end
    end

    def run()
      threads = []
      threads << @remote_tcp.tcp_thread if @remote_tcp != nil
      threads << Thread.new do
        loop do
          # if need content data
          if @last_update_timestamp.nil?
            sleep_time_span = Params['remote_content_timeout']
          else
            sleep_time_span = Time.now.to_i - @last_update_timestamp
          end

          if sleep_time_span >= Params['remote_content_timeout']
            # Send ping!
            Log.debug2('Sending remote contend request.')
            bytes_written = @remote_tcp.send_obj(nil)
            Log.debug3("Bytes written #{bytes_written}.")
          end

          sleep_time_span = Time.now.to_i - @last_update_timestamp \
                unless @last_update_timestamp.nil?
          Log.debug2("sleep_time_span: #{sleep_time_span}")
          sleep(sleep_time_span) if sleep_time_span > 0
        end
      end
    end
  end

  class RemoteContentClient
    def initialize(dynamic_content_data, port)
      @dynamic_content_data = dynamic_content_data
      @tcp_server = Networking::TCPServer.new(port, method(:content_requested))
    end

    def content_requested(addr_info, message)
      # Send response.
      Log.debug1('Local content data requested.')
      @tcp_server.send_obj(@dynamic_content_data.last_content_data)
    end

    def tcp_thread
      return @tcp_server.tcp_thread if @tcp_server != nil
      nil
    end

  end

end

