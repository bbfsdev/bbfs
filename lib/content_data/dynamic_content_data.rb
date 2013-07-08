require 'thread'

require 'content_server/server'
require 'params'

module ContentData

  # TODO(kolman): When content data is immutable, remove the clones (waste).
  class DynamicContentData
    def initialize()
      @last_content_data = nil
      @last_content_data_available_mutex = Mutex.new
    end

    def update(content_data)
      @last_content_data_available_mutex.synchronize {
        @last_content_data = content_data
        Log.debug2("updating last content data:#{@last_content_data}\n")
      }
    end

    def exists?(checksum)
      ref = nil
      @last_content_data_available_mutex.synchronize {
        ref = @last_content_data
      }
      return ref.content_exists(checksum) if ref != nil
      false
    end

    def each_instance(&block)
      ref = nil
      @last_content_data_available_mutex.synchronize {
        ref = @last_content_data
      }
      ref.each_instance(&block)
    end

    def add_instance(checksum, size, server_name, path, modification_time)
      @last_content_data_available_mutex.synchronize {
        @last_content_data.add_instance(checksum, size, server_name, path, modification_time)
      }
    end

    def remove_instance(server, path)
      @last_content_data_available_mutex.synchronize {
        @last_content_data.remove_instance(server, path)
      }
    end

    def remove_directory(server, path)
      @last_content_data_available_mutex.synchronize {
        @last_content_data.remove_directory(path, server)
      }
    end

    def stats_by_location(location)
      ref = nil
      @last_content_data_available_mutex.synchronize {
        ref = @last_content_data
      }
      return ref.stats_by_location(location)
    end

    def last_content_data
      ref = nil
      @last_content_data_available_mutex.synchronize {
        ref = @last_content_data
      }
      return ref
    end
  end

end  # module ContentData
