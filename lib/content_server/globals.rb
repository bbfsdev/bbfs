require 'process_monitoring/thread_safe_hash'

module ContentServer
  class Globals
    @@process_vars = ThreadSafeHash::ThreadSafeHash.new
    def self.process_vars
      @@process_vars
    end
  end
end