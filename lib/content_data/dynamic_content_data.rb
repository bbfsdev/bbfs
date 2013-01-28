require 'thread'

module ContentData

  # TODO(kolman): When content data is immutable, remove the clones (waste).
  class DynamicContentData
    def initialize()
      @last_content_data = nil
      @last_content_data_available_mutex = Mutex.new
    end

    def update(content_data)
      ref = ContentData.new(content_data)
      @last_content_data_available_mutex.synchronize {
        @last_content_data = ref
      }
    end

    def exists?(checksum)
      ref = nil
      @last_content_data_available_mutex.synchronize {
        ref = @last_content_data
      }
      #Log.debug3("@last_content_data is nil? #{@last_content_data.nil?}")
      #Log.debug3(@last_content_data.to_s) unless @last_content_data.nil?
      #Log.debug3("Exists?:#{@last_content_data.content_exists(checksum)}") \
      #         unless @last_content_data.nil?
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
