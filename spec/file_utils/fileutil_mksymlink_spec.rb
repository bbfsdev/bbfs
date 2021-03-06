# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'file_utils'
end
require 'fileutils'
require 'rspec'

require_relative '../../lib/content_data/content_data'
require_relative '../../lib/file_indexing/index_agent'
require_relative '../../lib/file_utils/file_utils'

module FileUtils
  module Spec

    describe 'File Util Mk Dir Sym Link Test' do
      # directory where tested files will be placed: <application_root_dir>/tests/../resources/time_modification_test
      MKSYMLINKS_RESOURCES_DIR = File.expand_path(File.dirname(__FILE__) + "/mksymlink_test")
      REF_DIR = MKSYMLINKS_RESOURCES_DIR + "/ref"
      DEST_DIR = MKSYMLINKS_RESOURCES_DIR + "/dest"
      NOT_FOUND_CHECKSUM = "absent_instance"
      @ref_db
      @base_db

      before :all do
        Params.init Array.new
        # must preced Log.init, otherwise log containing default values will be created
        Params['log_write_to_file'] = false
        Log.init

        sizes = [500, 1000, 1500]
        numb_of_copies = 2
        test_file_name = "test_file"   # file name format: <test_file_name_prefix>.<size>[.serial_number_if_more_then_1]

        ::FileUtils.rm_rf(MKSYMLINKS_RESOURCES_DIR) if (File.exists?(MKSYMLINKS_RESOURCES_DIR))

        # prepare files for testing
        cur_dir = nil; # dir where currently files created in this iteration will be placed
        only_in_base = Array.new # files that will be only in base

        sizes.each do |size|
          file_name = test_file_name + "." + size.to_s

          if (cur_dir == nil)
            cur_dir = String.new(MKSYMLINKS_RESOURCES_DIR)
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
        patterns.add_pattern(MKSYMLINKS_RESOURCES_DIR + '\**\*')
        indexer.index(patterns)

        @base_db = indexer.indexed_content
        @ref_db = ContentData::ContentData.new

        @base_db.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
          unless only_in_base.include?(path)
            file_name = File.basename(path)
            base_dir = File.dirname(path)
            ref_full_path = String.new(REF_DIR)
            if (base_dir == MKSYMLINKS_RESOURCES_DIR)
              ref_full_path << "/dir/#{file_name}"
            else
              ref_full_path << "/#{file_name}"
            end
            @ref_db.add_instance(checksum, size, server, path, instance_mod_time)
          end
        }
        @ref_db.add_instance(NOT_FOUND_CHECKSUM, 500, `hostname`.chomp, "/not/exist/path/file", Time.now.utc.to_i)
      end

      after :all do
        ::FileUtils.rm_rf(MKSYMLINKS_RESOURCES_DIR) if (File.exists?(MKSYMLINKS_RESOURCES_DIR))
      end

      it 'test create symlink structure' do
        not_found_db = nil
        begin
          not_found_db = FileUtils.mksymlink(@ref_db, @base_db, DEST_DIR)
        rescue NotImplementedError
          (RUBY_PLATFORM =~ /mingw/ || RUBY_PLATFORM =~ /ms/ || RUBY_PLATFORM =~ /win/).should be_true \
                    'Symbolics links should be implemented for non windows platforms.'
          return
        end

        base_path2checksum = Hash.new
        @base_db.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
          base_path2checksum[path] = checksum
        }

        not_found_path2checksum = {}
        not_found_db_contents_size = 0
        not_found_db_instances_size = 0
        not_found_db.each_content { |checksum, size, content_mod_time| not_found_db_contents_size += 1}
        not_found_db.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
          not_found_path2checksum[path] = checksum
          not_found_db_instances_size += 1
        }

        @ref_db.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
          next if not_found_path2checksum.has_key?(path)
          ref_path = DEST_DIR + path
          (File.exists?(ref_path)).should be_true
          (File.symlink?(ref_path)).should be_true
          base_file = File.expand_path(File.readlink(ref_path))
          base_checksum = base_path2checksum[base_file]
          base_checksum.should == checksum
        }

        if (not_found_db == nil)
          not_found_db.should_not be_nil
        else
          1.should == not_found_db_contents_size
          1.should == not_found_db_instances_size
          (not_found_db.content_exists NOT_FOUND_CHECKSUM).should be_true
        end
      end
    end
  end
end
