# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_data'
end
require 'rspec'
require 'file_indexing/index_agent'
require 'params'
require_relative '../../lib/content_data.rb'

module ContentData
  module Spec
    describe 'Index validation' do
      before :all do
        @size = 100
        @path = '/dir1/dir2/file'
        @path2 = '/dir3/dir4/file'
        @mod_time = 123456
        @checksum = 'abcde987654321'
        @checksum2 = '987654321abcde'
        @server = 'server_1'
      end

      before :each do
        @index = ContentData.new
        @index.add_instance @checksum, @size, @server, @path, @mod_time
        @index.add_instance @checksum2, @size, @server, @path2, @mod_time
      end

      context 'with shallow check' do
        before :all do
          Params['instance_check_level'] = 'shallow'
        end

        before :each do
          File.stub(:exists?).and_return(true)
          File.stub(:size).and_return(@size)
          File.stub(:mtime).and_return(@mod_time)
        end

        it 'succeeds when files exist and their attributes the same as in the index' do
          @index.validate().should be_true
        end

        it 'fails when there is a file that doesn\'t exist' do
          File.stub(:exists?).with(@path).and_return(false)
          @index.validate().should be_false
        end

        it 'fails when there is a file with size different from indexed' do
          File.stub(:size).with(@path).and_return(@size + 10)
          @index.validate().should be_false
        end

        it 'fails when there is a file with  modification time different from indexed' do
          modified_mtime = @mod_time + 10
          File.stub(:mtime).with(@path).and_return(modified_mtime)
          @index.validate().should be_false
        end
      end

      context 'with deep check (shallow check assumed succeeded)' do
        before :all do
          Params['instance_check_level'] = 'deep'
        end

        before :each do
          FileIndexing::IndexAgent.stub(:get_checksum).with(@path).and_return(@checksum)
          FileIndexing::IndexAgent.stub(:get_checksum).with(@path2).and_return(@checksum2)
          @index.stub(:shallow_check).and_return(true)
        end

        it 'succeeds when for all files checksums are the same as indexed' do
          @index.validate().should be_true
        end

        it 'fails when there is a file with checksum different from indexed' do
          FileIndexing::IndexAgent.stub(:get_checksum).with(@path2).and_return(@checksum2 + 'a')
          @index.validate().should be_false
        end
      end

      context 'validation params' do
        before :all do
          Params['instance_check_level'] = 'shallow'
        end

        before :each do
          File.stub(:exists?).and_return(true)
          File.stub(:size).and_return(@size)
          File.stub(:mtime).and_return(@mod_time)
        end

        it ':failed param returns index of absent or invalid instances' do
          # one instance that absent,
          absent_checksum = '123'
          absent_path = @path2 + '1'
          @index.add_instance absent_checksum, @size, @server, absent_path, @mod_time
          File.stub(:exists?).with(absent_path).and_return(false)

          # another instance with different content was changed
          File.stub(:mtime).with(@path2).and_return(@mod_time + 10)

          failed = ContentData.new
          @index.validate(:failed => failed).should be_false
          # should be two failed contents, with one instance per content
          failed.contents_size.should eq(2)
          failed.content_exists(absent_checksum).should be_true
          failed.content_exists(@checksum2).should be_true
          failed.checksum_instances_size(absent_checksum).should eq(1)
          failed.checksum_instances_size(@checksum2).should eq(1)
          failed.instance_exists(absent_path, @server).should be_true
          failed.instance_exists(@path2, @server).should be_true
        end
      end
    end
  end
end
