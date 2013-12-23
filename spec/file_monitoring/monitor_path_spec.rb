require 'rspec'

require_relative '../../lib/file_monitoring/monitor_path.rb'

module FileMonitoring
  module Spec

    describe 'monitoring' do

      # disabling log before running 'all' tests
      before :all do
        DirStat.set_log(nil)
      end

      # Test will create a monitoring directory.
      # Test will setup dummy files for glob.
      #   1st file is a regular file. 2nd file is a symlink file.
      # Test will check that regular file added to dir
      # Test will check the symlink file was ignored (not added to dir)
      it 'should ignore symlink files during monitoring' do

        # create the directory
        dir_stat = DirStat.new('temp_path')

        # define stubs for: glob, symlink checks and file status object(lstat).
        Dir.stub(:glob).with('temp_path/*').and_return(['regular_file','symlink_file'])
        File.stub(:symlink?).with('regular_file').and_return(false)
        File.stub(:symlink?).with('symlink_file').and_return(true)
        return_lstat = File.lstat(__FILE__)
        File.stub(:lstat).with(any_args).and_return(return_lstat)

        # Perform monitoring
        dir_stat.monitor

        # check that 'regular_file' was added to Dir
        dir_stat.instance_eval{@files}['regular_file'].nil?.should be(false)
        # check that 'symlink_file' was ignored( not added to Dir)
        dir_stat.instance_eval{@files}['symlink_file'].nil?.should be(true)

      end
    end
  end
end
