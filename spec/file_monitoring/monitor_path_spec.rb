require 'rspec'

require_relative '../../lib/file_monitoring/monitor_path.rb'

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
        @dir_stat.instance_eval{@files}['regular_file'].nil?.should be(false)
        # check that 'symlink_file' was not added to @files map under DirStat
        @dir_stat.instance_eval{@files}['symlink_file'].nil?.should be(true)
        # check that 'symlink_file' was added to @symlinks map under DirStat
        expect(@dir_stat.instance_eval{@symlinks}['symlink_file']).to eq('symlink_target')
        # check that 'symlink file' was added to content data object
        symlink_key = [`hostname`.strip, 'symlink_file']
        expect($local_content_data.instance_eval{@symlinks_info}[symlink_key]).to eq('symlink_target')

      end

      # Test will setup regular_file for glob from previous test.
      # Test will check the symlink file was deleted from dir
      it 'should delete the symlink file from previous test' do

        # define stubs for: glob, symlink checks and file status object(lstat).
        Dir.stub(:glob).with('temp_path/*').and_return(['regular_file'])
        File.stub(:symlink?).with('regular_file').and_return(false)
        return_lstat = File.lstat(__FILE__)
        File.stub(:lstat).with(any_args).and_return(return_lstat)

        # Perform monitoring
        @dir_stat.monitor

        # check that 'symlink_file' was deleted from @symlinks map under DirStat
        expect(@dir_stat.instance_eval{@symlinks}['symlink_file']).to eq(nil)
        # check that 'symlink file' was deleted from content data object
        symlink_key = [`hostname`.strip, 'symlink_file']
        expect($local_content_data.instance_eval{@symlinks_info}[symlink_key]).to eq(nil)

      end
    end
  end
end
