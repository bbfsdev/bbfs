# Author: Kolman Vornovitsky (kolmanv@gmail.com)
# Run from bbfs> ruby -Ilib examples/file_indexing.rb

require 'file_indexing'

# Helper variable: directory of current example file!
LOCAL_PATH = File.expand_path File.dirname(__FILE__)
# Directory of example files.
FILES_DIR = File.join(LOCAL_PATH, 'file_indexing')

# Problem: Suppose we want to calculate SHA1 of a set of files. This action is called indexing.
# Solution: Lets create an index_agent
index_agent = FileIndexing::IndexAgent.new
# and index_patters which are set of positive and negative globs.
# What is glob: http://www.ruby-doc.org/core-1.9.3/Dir.html#method-c-glob
indexer_patterns = FileIndexing::IndexerPatterns.new
indexer_patterns.add_pattern File.join(FILES_DIR, '/*')
# If you want to filter out (remove) some files and not index them you can use similar glob
# with is_positive variable set to false.
indexer_patterns.add_pattern(File.join(FILES_DIR, '/*.tmp'), false)

# Now lets run the indexer:
index_agent.index(indexer_patterns)
# The indexer reads each file matching the positive globs and not matching the negative globs, it
# calculates SHA1 and fills data structure called ContentData.

# Lets get the content data and print it.
cd = index_agent.indexed_content
# Note that only one file was indexed! This is because the false pattern was applied to .tmp file!
p cd.to_s
# The end!
