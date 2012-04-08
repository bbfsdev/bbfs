require_relative 'file_indexing/index_agent'
require_relative 'file_indexing/indexer_patterns'

# Data structure for an abstract layer over files.
# Each binary sequence is a content, each file is content instance.
module BBFS
  module FileIndexing
    VERSION = "0.0.1"
  end
end
