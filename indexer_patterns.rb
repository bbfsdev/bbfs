class IndexerPatterns
  attr_reader :positive_patterns, :negative_patterns

  def initialize
    @positive_patterns = Array.new
    @negative_patterns = Array.new
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
      puts "Error loading patterns=%s" % file
      raise IOError("Error loading patterns=%s" % file)
    end unless not input_patterns.nil?

    input_patterns.each do |pattern|
      if (m = /^\s*([+-]):(.*)/.match(pattern))
        add_pattern(m[2], m[1].eql?('+') ? true : false)
      elsif (not /^\s*[\/\/|#]/.match(pattern))   # not a comment
        puts "pattern in incorrect format: #{pattern}"
        raise RuntimeError("pattern in incorrect format: #{pattern}")
      end
    end
  end
end