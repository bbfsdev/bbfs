Gem::Specification.new do |s|
  s.name        = 'file_indexing'
  s.version     = '0.0.1'
  s.summary     = 'Indexes files.'
  s.description = 'Indexes files, treats files with same binary sequence as one content.'
  s.authors     = ['Gena Petelko, Kolman Vornovitsky']
  s.email       = 'kolmanv@gmail.com'
  s.homepage    = 'http://github.com/kolmanv/bbfs'
  s.files       = ['lib/file_indexing.rb',
                   'lib/file_indexing/index_agent.rb',
                   'lib/file_indexing/indexer_patterns.rb']
#  s.test_files  = ['test/file_indexing/file_indexing_spec.rb']
  s.add_dependency('content_data')
end
