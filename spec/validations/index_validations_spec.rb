require 'rspec'
require_relative '../../lib/validations.rb'

module Validations
  module Spec
    describe 'Index validation' do
      context 'of index from other file system' do
        before :all do
          @size = 100
          @path = '/dir1/dir2/file'
          @path2 = '/dir3/dir4/file'
          @path3 = '/dir5/dir6/file'
          @path4 = '/dir7/dir8/file'
          @mod_time = 123456
          @checksum = 'abcde987654321'
          @checksum2 = '987654321abcde'
        end

        before :each do
          @index = ContentData::ContentData.new
          @remote_index = ContentData::ContentData.new

          @content = double :content, :checksum => @checksum,
            :size => @size, :first_appearance_time => @mod_time
          @content2 = double :content2, :checksum => @checksum2,
            :size => @size, :first_appearance_time => @mod_time

          @instance = double :instance, :checksum => @checksum, :global_path => @path,
            :size => @size, :full_path => @path, :modification_time => @mod_time
          @instance2 = double :instance2, :checksum => @checksum2, :global_path => @path2,
            :size => @size, :full_path => @path2, :modification_time => @mod_time
          @instance3 = double :instance3, :checksum => @checksum, :global_path => @path3,
            :size => @size, :full_path => @path3, :modification_time => @mod_time
          @instance4 = double :instance4, :checksum => @checksum2, :global_path => @path4,
            :size => @size, :full_path => @path4, :modification_time => @mod_time

          @index.add_content @content
          @index.add_content @content2
          @index.add_instance @instance
          @index.add_instance @instance2

          @remote_index.add_content @content
          @remote_index.add_content @content2
          @remote_index.add_instance @instance3
          @remote_index.add_instance @instance4

          File.stub(:exists?).and_return(true)
          File.stub(:size).and_return(@size)
          File.stub(:mtime).and_return(@mod_time)
          #ContentData::ContentData.stub(:format_time).with(@mod_time).and_return(@mod_time)
          Params['instance_check_level'] = 'shallow'
        end

        it 'succeeds when all remote contents has valid local instance' do
          IndexValidations.validate_remote_index(@remote_index, @index).should be_true
        end

        it 'fails when remote content is absent' do
          absent_checksum = '123'
          absent_content = double :absent_content, :checksum => absent_checksum, \
            :size => @size, :first_appearance_time => @mod_time
          @remote_index.add_content absent_content
          IndexValidations.validate_remote_index(@remote_index, @index).should be_false
        end

        it 'fails when local instance of remote content is invalid' do
          modified_mtime = @mod_time + 10
          File.stub(:mtime).with(@path).and_return(modified_mtime)
          #ContentData::ContentData.stub(:format_time).with(modified_mtime).and_return(modified_mtime)
          IndexValidations.validate_remote_index(@remote_index, @index).should be_false
        end

        it ':failed param returns index of absent contents or contents without valid instances' do
          absent_checksum = '123'
          absent_path = '/dir9/dir10/absent_file'
          absent_content = double :absent_content, :checksum => absent_checksum, \
            :size => @size, :first_appearance_time => @mod_time
          absent_instance = double :instance, :checksum => absent_checksum, :global_path => absent_path,
            :size => @size, :full_path => absent_path, :modification_time => @mod_time
          @remote_index.add_content absent_content
          @remote_index.add_instance absent_instance

          # invalid instance has @path2 path on local and @path4 on remote
          modified_mtime = @mod_time + 10
          File.stub(:mtime).with(@path2).and_return(modified_mtime)
          #ContentData::ContentData.stub(:format_time).with(modified_mtime).and_return(modified_mtime)

          failed = ContentData::ContentData.new
          IndexValidations.validate_remote_index(@remote_index, @index, :failed => failed)
          failed.contents.should have(2).items
          failed.contents.keys.should include(absent_checksum, @checksum2)
          failed.instances.should have(2).items
          failed.instances.keys.should include(@path4)

        end
      end
    end
  end
end

