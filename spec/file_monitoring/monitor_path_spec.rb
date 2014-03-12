# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'file_monitoring'
end
require './lib/file_monitoring/monitor_path'
require 'rspec'
require 'fileutils'

module FileMonitoring
  module Spec

    describe 'monitoring' do

      before :all do
        # initial global local content data object
        $local_content_data_lock = Mutex.new
        $local_content_data = ContentData::ContentData.new

        # disabling log before running 'all' tests
        DirStat.set_log(nil)

        # create the directory
        @dir_stat = DirStat.new('temp_path')
      end

      # Test will: 
      # 1) Create a monitoring directory.
      # 2) Setup dummy files for glob.
      #   - test files with same key (name, mod time, size), i.e., unique/non-unique.
      #   - test with marked and unmarked files.
      # 3) Preform monitoring.
      # 4) Check that files were added as needed.
      # 4) Stop and move files to different directory.
      #   - move existing file to other directory
      #   - create new file.
      # 5) Perform monitoring with Params['manual_file_changes']=true.
      # 6) Test will check that all files were moved appropriatly without reindexing.
      it 'should not index moved files in manual_file_changes mode' do
        # Return X times some files, then other files.
        X = ::FileMonitoring.stable_state + 1
        return_files = Array.new(X, ['temp_path/const_file', 'temp_path/will_be_deleted_file', 'temp_path/will_be_moved_file'])
        return_files << ['temp_path/const_file', 'temp_path/a_dir']
        Dir.stub(:glob).with('temp_path/*').and_return(*return_files)
        File.stub(:symlink?).and_return(false)
        stat = Object.new
        stat.stub(:mtime).and_return(111)
        stat.stub(:file?).and_return(true)
        stat.stub(:size).and_return(222)
        File.stub(:lstat).with(any_args).and_return(stat)
        File.stub(:open).and_return("dummy file content!")

        print "##### Monitor 5 times #####\n"
        # Perform monitoring
        X.times do
          @dir_stat.monitor
          @dir_stat.removed_unmarked_paths
          @dir_stat.index
        end
        files = @dir_stat.instance_variable_get(:@files)
        print files
        print "\n"
        files.has_key?('temp_path/const_file').should be(true)
        files.has_key?('temp_path/will_be_deleted_file').should be(true)
        files.has_key?('temp_path/will_be_moved_file').should be(true)

        Dir.stub(:glob).with('temp_path/a_dir/*').and_return(['temp_path/a_dir/will_be_moved_file'])
        dir_lstat = Object.new
        dir_lstat.stub(:mtime).and_return(123)
        dir_lstat.stub(:file?).and_return(false)
        dir_lstat.stub(:size).and_return(333)
        File.stub(:lstat).with('temp_path/a_dir').and_return(dir_lstat)

        get_params_method = Params.method(:[])
        Params.stub(:[]).and_return do |arg|
          get_params_method.call(arg)
        end
        Params.stub(:[]).with('manual_file_changes').and_return(true)

        # Build file_attr_to_checksum for the second monitor run...
        file_attr_to_checksum = {}
        file_attr_to_checksum[['const_file', 222, 111]] = IdentFileInfo.new('checksum1', 1)
        file_attr_to_checksum[['will_be_deleted_file', 222, 111]] = IdentFileInfo.new('checksum2', 1)
        file_attr_to_checksum[['will_be_moved_file', 222, 111]] = IdentFileInfo.new('checksum3', 1)

        print "##### Monitor with manual file changes #####\n"
        # Second round monitoring with manual_file_changes as true
        @dir_stat.monitor(file_attr_to_checksum)
        @dir_stat.removed_unmarked_paths
        @dir_stat.index

        print $local_content_data.instance_variable_get(:@instances_info)
        print "\n"

        Params.stub(:[]).with('manual_file_changes').and_return(false)
        print "##### Monitor last time (standard) #####\n"
        # Third round monitoring with manual_file_changes as false but with file_attr_to_checksum
        @dir_stat.monitor
        @dir_stat.removed_unmarked_paths
        @dir_stat.index

        # check that files were added to Dir
        files = @dir_stat.instance_variable_get(:@files)
        print files
        print "\n"
        files.has_key?('temp_path/const_file').should be(true)
        files.has_key?('temp_path/will_be_deleted_file').should be(false)
        files.has_key?('temp_path/will_be_moved').should be(false)
        dirs = @dir_stat.instance_variable_get(:@dirs)
        print dirs
        print "\n"
        dirs.has_key?('temp_path/a_dir').should be(true)
        a_dir_files = dirs['temp_path/a_dir'].instance_variable_get(:@files)
        print a_dir_files
        print "\n"
        a_dir_files.has_key?('temp_path/a_dir/will_be_moved_file').should be(true)

        print $local_content_data.instance_variable_get(:@instances_info)
        print "\n"
        instances = $local_content_data.instance_variable_get(:@instances_info)
        instances.has_key?([Params['local_server_name'], 'temp_path/const_file']).should be(true)
        instances.has_key?([Params['local_server_name'], 'temp_path/will_be_deleted_file']).should be(false)
        instances.has_key?([Params['local_server_name'], 'temp_path/a_dir/will_be_moved_file']).should be(true)
      end
      

      # Test will create a monitoring directory.
      # Test will setup dummy files for glob.
      #   1st file is a regular file. 2nd file is a symlink file.
      # Test will check that regular file added to dir
      # Test will check the symlink file was ignored (not added to dir)
      it 'should add a regular file and a symlink file during monitoring' do
        # define stubs for: glob, symlink checks and file status object(lstat).
        Dir.stub(:glob).with('temp_path/*').and_return(['regular_file','symlink_file'])
        File.stub(:symlink?).with('regular_file').and_return(false)
        File.stub(:symlink?).with('symlink_file').and_return(true)
        return_lstat = File.lstat(__FILE__)
        File.stub(:lstat).with(any_args).and_return(return_lstat)
        File.stub(:readlink).with('symlink_file').and_return('symlink_target')
        # Perform monitoring
        @dir_stat.monitor

        # check that 'regular_file' was added to @files map under DirStat
        @dir_stat.instance_variable_get(:@files).has_key?('regular_file').should be(true)
        # check that 'symlink_file' was not added to @files map under DirStat
        @dir_stat.instance_variable_get(:@files).has_key?('symlink_file').should be(false)
        # check that 'symlink_file' was added to @symlinks map under DirStat
        expect(@dir_stat.instance_variable_get(:@symlinks)['symlink_file']).to eq('symlink_target')
        # check that 'symlink file' was added to content data object
        symlink_key = [`hostname`.strip, 'symlink_file']
        expect($local_content_data.instance_variable_get(:@symlinks_info)[symlink_key]).to eq('symlink_target')
      end

      # Test will setup regular_file for glob from previous test.
      # Test will check the symlink file was deleted from dir
      it 'should delete the symlink file from previous test' do
        # define stubs for: glob, symlink checks and file status object(lstat).
        Dir.stub(:glob).with('temp_path/*').and_return(['regular_file'])
        File.stub(:symlink?).with('regular_file').and_return(false)
        return_lstat = File.lstat(__FILE__)
        File.stub(:lstat).with(any_args).and_return(return_lstat)

        # check that 'symlink file' exists before monitoring
        symlink_key = [`hostname`.strip, 'symlink_file']
        $local_content_data.instance_variable_get(:@symlinks_info).has_key?(symlink_key).should be(true)

        # Perform monitoring
        @dir_stat.monitor

        # check that 'symlink_file' was deleted from @symlinks map under DirStat
        @dir_stat.instance_variable_get(:@symlinks).has_key?('symlink_file').should be(false)
        # check that 'symlink file' was deleted from content data object
        $local_content_data.instance_variable_get(:@symlinks_info).has_key?(symlink_key).should be(false)
      end
    end
  end
end
