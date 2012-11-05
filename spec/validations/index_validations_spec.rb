require 'rspec'
require 'file_indexing/index_agent'

require_relative '../../lib/validations.rb'

module BBFS
  module Validations
    module Spec
      describe 'Index validations' do
        before :all do
          @size = 100
          @path = '/dir1/dir2/file'
          @path2 = '/dir3/dir4/file'
          @mod_time = 123456
          @checksum = 'abcde987654321'
          @checksum2 = '987654321abcde'
        end

        before :each do
          @instance = double :instance, :checksum => @checksum, \
            :size => @size, :full_path => @path, :modification_time => @mod_time
          @instance2 = double :instance2, :checksum => @checksum2, \
            :size => @size, :full_path => @path2, :modification_time => @mod_time
          @instances = Hash.new
          @instances[@checksum] = @instance
          @instances[@checksum2] = @instance2
          @index = double(:index, :instances => @instances)
        end

        context 'with shallow check' do
          before :each do
            File.stub(:exists?).with(@path).and_return(true)
            File.stub(:size).with(@path).and_return(@size)
            File.stub(:mtime).with(@path).and_return(@mod_time)

            File.stub(:exists?).with(@path2).and_return(true)
            File.stub(:size).with(@path2).and_return(@size)
            File.stub(:mtime).with(@path2).and_return(@mod_time)
          end

          it 'succeed when files exist and their attributes the same as in the index' do
            IndexValidations.validate_index(@index).should be_true
          end

          it 'fail when there is a file that doesn\'t exist' do
            File.stub(:exists?).with(@path).and_return(false)
            IndexValidations.validate_index(@index).should be_false
          end

          it 'fail when there is a file with size different from indexed' do
            File.stub(:size).with(@path).and_return(@size + 10)
            IndexValidations.validate_index(@index).should be_false
          end

          it 'fail when there is a file with  modification time different from indexed' do
            File.stub(:mtime).with(@path).and_return(@mod_time + 10)
            IndexValidations.validate_index(@index).should be_false
          end
        end

        context 'with deep check (shallow check assumed succeeded)' do
          before :all do
            Params['instance_check_level'] = 'deep'
          end

          before :each do
            FileIndexing::IndexAgent.stub(:get_checksum).with(@path).and_return(@checksum)
            IndexValidations.stub(:shallow_check).and_return(true)
            IndexValidations.stub(:shallow_check).and_return(true)
          end

          it 'succeed when for all files checksums are the same as indexed' do
            FileIndexing::IndexAgent.stub(:get_checksum).with(@path2).and_return(@checksum2)
            IndexValidations.validate_index(@index).should be_true
          end

          it 'fail when there is a file with checksum different from indexed' do
            FileIndexing::IndexAgent.stub(:get_checksum).with(@path2).and_return(@checksum2 + 'a')
            IndexValidations.validate_index(@index).should be_false
          end
        end
      end
    end
  end
end

