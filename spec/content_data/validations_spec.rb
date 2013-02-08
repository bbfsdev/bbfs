require 'rspec'
require 'file_indexing/index_agent'
require 'params'
require_relative '../../lib/content_data.rb'

module BBFS
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
        end

        before :each do
          @index = ContentData.new

          @content = double :content, :checksum => @checksum,
            :size => @size, :first_appearance_time => @mod_time
          @content2 = double :content2, :checksum => @checksum2,
            :size => @size, :first_appearance_time => @mod_time
          @index.add_content @content
          @index.add_content @content2

          @instance = double :instance, :checksum => @checksum, :global_path => @path,
            :size => @size, :full_path => @path, :modification_time => @mod_time
          @instance2 = double :instance2, :checksum => @checksum2, :global_path => @path2,
            :size => @size, :full_path => @path2, :modification_time => @mod_time
          @index.add_instance @instance
          @index.add_instance @instance2
        end

        context 'with shallow check' do
          before :all do
            Params['instance_check_level'] = 'shallow'
          end

          before :each do
            File.stub(:exists?).and_return(true)
            File.stub(:size).and_return(@size)
            File.stub(:mtime).and_return(@mod_time)
            #ContentData.stub(:format_time).with(@mod_time).and_return(@mod_time)
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
            #ContentData.stub(:format_time).with(modified_mtime).and_return(modified_mtime)
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
            absent_checksum = '123'
            absent_path = @path2 + '1'
            absent_content = double :absent_content, :checksum => absent_checksum,
              :size => @size, :first_appearance_time => @mod_time
            absent_instance = double :absent_instance, :checksum => absent_checksum,
              :global_path => absent_path, :size => @size, :full_path => absent_path,
              :modification_time => @mod_time
            @index.add_content absent_content
            @index.add_instance absent_instance
            File.stub(:exists?).with(absent_path).and_return(false)

            File.stub(:mtime).with(@path2).and_return(@mod_time + 10)

            failed = ContentData.new
            @index.validate(:failed => failed).should be_false
            failed.contents.should have(2).items
            failed.contents.keys.should include(absent_checksum, @checksum2)
            failed.instances.should have(2).items
            failed.instances.keys.should include(absent_path, @path2)
          end
        end
      end
    end
  end
end
