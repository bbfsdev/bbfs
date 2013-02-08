# Simple thread safe hash.
module ThreadSafeHash
  class ThreadSafeHash
    def initialize()
      @hash_data = Hash.new()
      @mutex = Mutex.new
    end

    def inc(key)
      @mutex.synchronize do
        value = @hash_data[key]
        if value.nil?
          @hash_data[key] = 1
        else
          @hash_data[key] = value + 1
        end
      end
    end

    def get(key)
      @mutex.synchronize do
        @hash_data[key]
      end
    end

    def set(key, value)
      @mutex.synchronize do
        @hash_data[key] = value
      end
    end

    def clone
      @mutex.synchronize do
        @hash_data.clone
      end
    end
  end
end

