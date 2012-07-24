# Author: Slava Pasechnik (slavapas13@gmail.com)
# Run from bbfs> ruby -Ilib test/file_generator/file_generator_spec.rb

require 'file_utils/file_generator/file_generator'
require 'rspec'

module BBFS
  module FileGenerator
    module Spec
      describe 'FileGenerator::run' do
        before(:each) do
          Params['file_size_in_mb'] = 50
          Params['total_created_directories'] = 1
          Params['total_files_in_dir'] = 1
          Params['is_tot_files_in_dir_random'] = false
          Params['is_use_random_size'] = false
          Params['sleep_time_in_seconds'] = 0
          Params['dir_name_prefix'] = "td4bs"
          Params['file_name_prefix'] = "agf4bs_"
        end

        it 'should reach File.open 1 files' do
          file = mock('file')
          file_utils_mkdir_p = double('FileUtils.mkdir_p')
          file_open = double('File.open')

          FileUtils.stub(:mkdir_p).and_return(file_utils_mkdir_p)
          File.stub(:open).and_return(file_open)
          File.should_receive(:open).exactly(1).times

          fg = BBFS::FileGenerator::FileGenerator.new()
          fg.run()
        end

        it 'should reach File.open 3 files' do
          file = mock('file')
          file_utils_mkdir_p = double('FileUtils.mkdir_p')
          file_open = double('File.open')

          FileUtils.stub(:mkdir_p).and_return(file_utils_mkdir_p)
          File.stub(:open).and_return(file_open)
          File.should_receive(:open).exactly(3).times

          Params['total_files_in_dir'] = 3
          fg = BBFS::FileGenerator::FileGenerator.new()
          fg.run()
        end

        it 'should reach File.open with prefixed dir and file names' do
          file = mock('file')
          file_utils_mkdir_p = double('FileUtils.mkdir_p')
          file_open = double('File.open')

          FileUtils.stub(:mkdir_p).and_return(file_utils_mkdir_p)
          File.stub(:open).and_return(file_open)
          File.should_receive(:open).with(/td4bs.*agf4bs_/, "w")

          fg = BBFS::FileGenerator::FileGenerator.new()
          fg.run()
        end

        it 'should reach File.open 3 files' do
          file = mock('file')
          file_utils_mkdir_p = double('FileUtils.mkdir_p')
          file_open = double('File.open')

          FileUtils.stub(:mkdir_p).and_return(file_utils_mkdir_p)
          File.stub(:open).and_return(file_open)
          File.should_receive(:open).exactly(3).times

          Params['total_files_in_dir'] = 3
          fg = BBFS::FileGenerator::FileGenerator.new()
          fg.run()
        end

        it 'should create filename and put text in it' do
          file = mock('file')
          File.should_receive(:open).with(any_args(), "w").and_yield(file)
          file.should_receive(:write).exactly(2).times

          fg = BBFS::FileGenerator::FileGenerator.new()
          fg.run()
        end
      end
    end
  end
end