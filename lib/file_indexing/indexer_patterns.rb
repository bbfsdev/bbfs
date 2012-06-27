require 'log'
require 'params'

module BBFS
  module FileIndexing

    class IndexerPatterns
      attr_reader :positive_patterns, :negative_patterns

      # @param indexer_patterns_str [String]
      def initialize (indexer_patterns = nil)
        Log.info "Initialize index patterns #{indexer_patterns}."
        @positive_patterns = Array.new
        @negative_patterns = Array.new
        # TODO add a test (including empty collections)
        if indexer_patterns
          indexer_patterns.positive_patterns.each do |pattern|
            add_pattern(pattern)
          end
          indexer_patterns.negative_patterns.each do |pattern|
            add_pattern(pattern, false)
          end
        end
      end

      def serialize
        # TODO add a test (including empty collections)
        indexer_patterns = IndexerPatternsMessage.new
        positive_patterns.each do |pattern|
          indexer_patterns.positive_patterns << pattern
        end
        negative_patterns.each do |pattern|
          indexer_patterns.negative_patterns << pattern
        end
        indexer_patterns
      end

      # @param pattern [String]
      # @param is_positive [true]
      # @param is_positive [false]
      def add_pattern(pattern, is_positive = true)
        pattern.gsub!(/\\/,'/')
        if (is_positive)
          @positive_patterns << pattern
        else
          @negative_patterns << pattern
        end
      end

      def parse_from_file(file)
        input_patterns = IO.readlines(file)
        begin
          Log.info "Error loading patterns=%s" % file
          raise IOError("Error loading patterns=%s" % file)
        end unless not input_patterns.nil?

        input_patterns.each do |pattern|
          if (m = /^\s*([+-]):(.*)/.match(pattern))
            add_pattern(m[2], m[1].eql?('+') ? true : false)
          elsif (not /^\s*[\/\/|#]/.match(pattern))   # not a comment
            Log.info "pattern in incorrect format: #{pattern}"
            raise RuntimeError("pattern in incorrect format: #{pattern}")
          end
        end
      end

      def size
        return @positive_patterns.size
      end
    end

  end
end
