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
          @server = 'server_1'
          @device = 'dev_1'
        end

        before :each do
          @index = ContentData::ContentData.new
          @index.add_instance @checksum, @size, @server, @device, @path, @mod_time
          @index.add_instance @checksum2, @size, @server, @device, @path2, @mod_time

          @remote_index = ContentData::ContentData.new
          @remote_index.add_instance @checksum, @size, @server, @device, @path3, @mod_time
          @remote_index.add_instance @checksum2, @size, @server, @device, @path4, @mod_time

          File.stub(:exists?).and_return(true)
          File.stub(:size).and_return(@size)
          File.stub(:mtime).and_return(@mod_time)
          Params['instance_check_level'] = 'shallow'
        end

        it 'succeeds when all remote contents has valid local instance' do
          IndexValidations.validate_remote_index(@remote_index, @index).should be_true
        end

        it 'fails when remote content is absent' do
          absent_checksum = '123'
          absent_path = '/dir9/dir10/absent_file'
          @remote_index.add_instance absent_checksum, @size, @server, @device, absent_path, @mod_time
          IndexValidations.validate_remote_index(@remote_index, @index).should be_false
        end

        it 'fails when local instance of remote content is invalid' do
          modified_mtime = @mod_time + 10
          File.stub(:mtime).with(@path).and_return(modified_mtime)
          IndexValidations.validate_remote_index(@remote_index, @index).should be_false
        end

        it ':failed param returns index of absent contents or contents without valid instances' do
          # one instance that absent,
          absent_checksum = '123'
          absent_path = '/dir9/dir10/absent_file'
          @remote_index.add_instance absent_checksum, @size, @server, @device, absent_path, @mod_time

          # invalid instance has @path2 path on local and @path4 on remote
          modified_mtime = @mod_time + 10
          File.stub(:mtime).with(@path2).and_return(modified_mtime)

          failed = ContentData::ContentData.new
          IndexValidations.validate_remote_index(@remote_index, @index, :failed => failed)
          # should be two failed contents, with one instance per content
          failed.contents_size.should eq(2)
          failed.content_exists(absent_checksum).should be_true
          failed.content_exists(@checksum2).should be_true
          failed.instances_size(absent_checksum).should eq(1)
          failed.instances_size(@checksum2).should eq(1)
          failed.instance_exists(absent_path, @server, @device, absent_checksum).should be_true
          failed.instance_exists(@path4, @server, @device, @checksum2).should be_true
        end
      end
    end
  end
end

