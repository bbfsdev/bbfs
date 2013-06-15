require 'thread'
require 'params'

module ContentData

  # TODO(kolman): When content data is immutable, remove the clones (waste).
  class DynamicContentData
    def initialize()
      @last_content_data = nil
      @last_content_data_available_mutex = Mutex.new

      #update last data in content directory
      ref = ContentData.new
      @content_data_path =Params['local_content_data_path']
      ref.from_file(@content_data_path) if File.exists?(@content_data_path)
      @last_content_data_available_mutex.synchronize {
        @last_content_data = ref
        Log.debug2("updating last content data:#{@last_content_data}\n")
      }if File.exists?(@content_data_path)


    end

    def update(content_data)
      ref = ContentData.new(content_data)
      @last_content_data_available_mutex.synchronize {
        @last_content_data = ref
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

    def last_content_data
      ref = nil
      @last_content_data_available_mutex.synchronize {
        ref = @last_content_data
      }
      return ContentData.new(ref)
    end
  end

end  # module ContentData
