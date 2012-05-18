require 'fileutils'
require 'test/unit'

require_relative '../../lib/content_data/content_data'
require_relative '../../lib/file_indexing/index_agent'
require_relative '../../lib/file_utils/file_utils'

module BBFS
  module FileUtils
    module Test

      class TestFileUtilMkDirSymLink < ::Test::Unit::TestCase
        # directory where tested files will be placed: <application_root_dir>/tests/../resources/time_modification_test
        RESOURCES_DIR = File.expand_path(File.dirname(__FILE__) + "/mksymlink_test")
        REF_DIR = RESOURCES_DIR + "/ref"
        DEST_DIR = RESOURCES_DIR + "/dest"
        DEVICE_NAME = "hd1"
        NOT_FOUND_CHECKSUM = "absent_instance"
        @ref_db
        @base_db

        def setup
          sizes = [500, 1000, 1500]
          numb_of_copies = 2
          test_file_name = "test_file"   # file name format: <test_file_name_prefix>.<size>[.serial_number_if_more_then_1]

          ::FileUtils.rm_rf(RESOURCES_DIR) if (File.exists?(RESOURCES_DIR))

          # prepare files for testing
          cur_dir = nil; # dir where currently files created in this iteration will be placed
          only_in_base = Array.new # files that will be only in base

          sizes.each do |size|
            file_name = test_file_name + "." + size.to_s

            if (cur_dir == nil)
              cur_dir = String.new(RESOURCES_DIR)
            else
              cur_dir = cur_dir + "/dir" + size.to_s
            end
            Dir.mkdir(cur_dir) unless (File.exists?(cur_dir))
            raise "Can't create writable working directory: #{cur_dir}" unless (File.exists?(cur_dir) and File.writable?(cur_dir))

            file_path = cur_dir + "/" + file_name
            only_in_base << file_path
            File.open(file_path, "w") do |file|
              content = Array.new
              size.times do |i|
                content.push(sprintf("%5d ", i))
              end
              file.puts(content)
            end

            numb_of_copies.times do |i|
              ::FileUtils.cp(file_path, "#{file_path}.#{i}")
            end
          end

          indexer = FileIndexing::IndexAgent.new  # (`hostname`.chomp, DEVICE_NAME)
          patterns = FileIndexing::IndexerPatterns.new
          patterns.add_pattern(RESOURCES_DIR + '\**\*')
          indexer.index(patterns)

          @base_db = indexer.indexed_content
          @ref_db = ContentData::ContentData.new

          @base_db.contents.each_value do |content|
            @ref_db.add_content(content)
          end


          @base_db.instances.each_value do |instance|
            unless only_in_base.include?(instance.full_path)
              file_name = File.basename(instance.full_path)
              base_dir = File.dirname(instance.full_path)
              ref_full_path = String.new(REF_DIR)
              if (base_dir == RESOURCES_DIR)
                ref_full_path << "/dir/#{file_name}"
              else
                ref_full_path << "/#{file_name}"
              end
              ref_instance = ContentData::ContentInstance.new(instance.checksum, instance.size, instance.server_name, instance.device, ref_full_path, instance.modification_time)
              @ref_db.add_instance(ref_instance)
            end

          end

          not_found_instance = ContentData::ContentInstance.new(NOT_FOUND_CHECKSUM, 500, `hostname`.chomp, DEVICE_NAME, "/not/exist/path/file", Time.now.utc)
          not_found_content = ContentData::Content.new(NOT_FOUND_CHECKSUM, not_found_instance.size, not_found_instance.modification_time)
          @ref_db.add_content(not_found_content)
          @ref_db.add_instance(not_found_instance)

        end

        def test_create_symlink_structure
          not_found_db = nil
          begin
            not_found_db = FileUtils.mksymlink(@ref_db, @base_db, DEST_DIR)
          rescue NotImplementedError
            assert RUBY_PLATFORM =~ /mingw/ || RUBY_PLATFORM =~ /ms/ || RUBY_PLATFORM =~ /win/, \
                    'Symbolics links should be implemented for non windows platforms.'
            return
          end

          base_path2checksum = Hash.new
          @base_db.instances.each_value do |instance|
            base_path2checksum[instance.full_path] = instance.checksum
          end
          not_found_path2checksum = Hash.new
          not_found_db.instances.each_value do |instance|
            not_found_path2checksum[instance.full_path] = instance.checksum
          end

          @ref_db.instances.each_value do |instance|
            ref_path = DEST_DIR + instance.full_path
            next if not_found_path2checksum.has_key?(instance.full_path)
            assert(File.exists?(ref_path))
            assert(File.symlink?(ref_path))
            base_file = File.expand_path(File.readlink(ref_path))
            base_checksum = base_path2checksum[base_file]
            assert_equal(instance.checksum, base_checksum)
          end

          if (not_found_db == nil)
            assert_not_nil(not_found_db)
          else
            assert_equal(not_found_db.contents.size, 1)
            assert_equal(not_found_db.instances.size, 1)
            assert(not_found_db.contents.has_key?NOT_FOUND_CHECKSUM)
          end
        end
      end


    end
  end
end
