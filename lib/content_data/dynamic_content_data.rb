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
      @last_content_data_available_mutex.synchronize {
        return @last_content_data.content_exists(checksum) if @last_content_data != nil
      }
      return false
    end

    def each_instance(&block)
      @last_content_data_available_mutex.synchronize {
        @last_content_data.each_instance(&block)
      }
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
        @last_content_data.remove_directory(server, path)
      }
    end

    def stats_by_location(location)
      @last_content_data_available_mutex.synchronize {
        return @last_content_data.stats_by_location(location)
      }
    end

    # TODO(kolman): This is not safe, i.e., content data may be changed
    # outside this function. For now all usages are read only.
    def last_content_data
      @last_content_data_available_mutex.synchronize {
        return @last_content_data
      }
    end
  end

end  # module ContentData
