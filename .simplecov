if ENV['BBFS_COVERAGE']
  SimpleCov.use_merging true
  SimpleCov.merge_timeout 3600
  SimpleCov.start do
    add_filter "/test/"
    add_filter "/spec/"
  end
end
