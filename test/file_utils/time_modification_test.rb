require 'time'
require 'test/unit'

require_relative '../../lib/content_data/content_data'
require_relative '../../lib/file_indexing/index_agent'
require_relative '../../lib/file_utils/fileutil'

module BBFS
  module FileUtils
    module Test
      class TestTimeModification < ::Test::Unit::TestCase
        # directory where tested files will be placed: __FILE__/time_modification_test
        RESOURCES_DIR = File.expand_path(File.dirname(__FILE__) + "/time_modification_test")
        # minimal time that will be inserted in content
        MOD_TIME_CONTENTS = ContentData::ContentData.parse_time("2001/02/01 02:23:59.000")
        # minimal time that will be inserted in instance
        MOD_TIME_INSTANCES = ContentData::ContentData.parse_time("2002/02/01 02:23:59.000")
        #time_str =  "2002/02/01 02:23:59.000"
        #MOD_TIME_INSTANCES = Time.strftime( time_str, '%Y/%m/%d %H:%M:%S.%L' )
        DEVICE_NAME = "hd1"

        @input_db
        @mod_content_checksum = nil  # checksum of the content that was manually modified
        @mod_instance_checksum = nil  # checksum of the instance that was manually modified

        def setup
          sizes = [500, 1000, 1500]
          numb_of_copies = 2
          test_file_name = "test_file"

          Dir.mkdir(RESOURCES_DIR) unless (File.exists?(RESOURCES_DIR))
          raise "Can't create writable working directory: #{RESOURCES_DIR}" unless (File.exists?(RESOURCES_DIR) and File.writable?(RESOURCES_DIR))
          # prepare files for testing
          sizes.each do |size|
            file_path = "#{RESOURCES_DIR}/#{test_file_name}.#{size}"
            File.open(file_path, "w", 0777) do |file|
              content = Array.new
              size.times do |i|
                content.push(sprintf("%5d ", i))
              end
              file.puts(content)
            end
            #file.close # looks like it redundant
            numb_of_copies.times do |i|
              ::FileUtils.cp(file_path, "#{file_path}.#{i}")
            end
          end

          indexer = FileIndexing::IndexAgent.new
          patterns = FileIndexing::IndexerPatterns.new
          patterns.add_pattern(RESOURCES_DIR + '\*')
          indexer.index(patterns)

          @input_db = ContentData::ContentData.new  # ContentData that will contain manually modified entries

          # modifying content
          indexer.indexed_content.contents.each_value do |content|
            if (@mod_content_checksum == nil)
              @input_db.add_content(ContentData::Content.new(content.checksum, content.size, MOD_TIME_CONTENTS))
              @mod_content_checksum = content.checksum
            else
              @input_db.add_content(content)
            end
          end

          # modifying instance that doesn't belong to the instances of modified content
          indexer.indexed_content.instances.each_value do |instance|
            if (instance.checksum != @mod_content_checksum and @mod_instance_checksum == nil)
              mod_instance = ContentData::ContentInstance.new(
                  instance.checksum, instance.size, instance.server_name,
                  instance.device, instance.full_path, MOD_TIME_INSTANCES)
              @input_db.add_instance(mod_instance)
              @mod_instance_checksum = instance.checksum
              # physically update modification time of the file
              File.utime(File.atime(instance.full_path), MOD_TIME_INSTANCES, instance.full_path)
            else
              @input_db.add_instance(instance)
            end
          end

          raise "one of the time modifications failed" unless @mod_content_checksum != nil && @mod_instance_checksum != nil
        end

        def test_modify
          # modified ContentData. Test files also were modified.
          mod_db = FileUtils.unify_time @input_db

          puts "==============="
          puts @input_db.to_s
          puts "==============="

          # checking that content was modified according to the instance with minimal time
          mod_db.contents.each_value do |content|
            if (content.checksum == @mod_instance_checksum)
              assert_equal(MOD_TIME_INSTANCES, content.first_appearance_time)
              break
            end
          end

          # checking that instances were modified according to the instance and content with minimal time
          mod_db.instances.each_value do |instance|
            if (instance.checksum == @mod_content_checksum)
              assert_equal(MOD_TIME_CONTENTS, instance.modification_time)
            elsif (instance.checksum == @mod_instance_checksum)
              assert_equal(MOD_TIME_INSTANCES, instance.modification_time)
            end
          end

          # checking that files were actually modified
          instance = mod_db.instances.values[0]
          indexer = FileIndexing::IndexAgent.new  # (instance.server_name, instance.device)
          patterns = FileIndexing::IndexerPatterns.new
          patterns.add_pattern(File.dirname(instance.full_path) + '/*')     # this pattern index all files
          indexer.index(patterns, mod_db)
          assert_equal(indexer.indexed_content, mod_db)
        end
      end
    end
  end
end
