if ENV['BBFS_COVERAGE']
  SimpleCov.use_merging true
  SimpleCov.merge_timeout 3600
  SimpleCov.start do
    # filter out files from the spec directory,
    # cause we do not interested in coverage report for them
    add_filter "/spec/"

    # filter out source files that do not have method definition
    add_filter do |source_file|
      method_line_index = source_file.lines.index { |line| line.src =~ /^\s*def / }
      method_line_index.nil?
    end
  end
end
