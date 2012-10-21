
module BBFS
  module ThreadSafeHash
    class ThreadSafeHash
      def initialize()
        @hash_data = Hash.new()
        @mutex = Mutex.new
      end

      #TODO (slava)
      #def inc(key)
      #  curVal = get(key)
      #  if value.nil?
      #    set(key, 1)
      #  else
      #    set(key, curVal + 1)
      #  end
      #end

      def get(key)
        mutex.synchronize do
          @hash_data[key]
        end
      end

      def set(key)
        mutex.synchronize do
          curVal = @hash_data[key]
          if curVal.nil?
            @hash_data[key] = 1
          else
            @hash_data[key] = curVal + 1
          end
        end
      end
    end
  end
end
