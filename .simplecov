if ENV['BBFS_COVERAGE']
  SimpleCov.use_merging true
  SimpleCov.merge_timeout 3600
  SimpleCov.start do
    # filter out files from the spec directory,
    # cause we do not interested to coverage report for them
    add_filter "/spec/"
  end
end
