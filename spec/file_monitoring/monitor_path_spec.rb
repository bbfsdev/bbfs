require 'rspec'

require_relative '../../lib/file_monitoring/monitor_path.rb'

module FileMonitoring
  module Spec

    describe 'monitoring' do

      # disabling log before running 'all' tests
      before :all do
        DirStat.set_log(nil)
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
        $local_content_data_lock = Mutex.new
        $local_content_data = ContentData::ContentData.new
        # create the directory
        dir_stat = DirStat.new('temp_path')

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
          dir_stat.monitor
          dir_stat.removed_unmarked_paths
          dir_stat.index
        end
        files = dir_stat.instance_variable_get(:@files)
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
        dir_stat.monitor(file_attr_to_checksum)
        dir_stat.removed_unmarked_paths
        dir_stat.index

        print $local_content_data.instance_variable_get(:@instances_info)
        print "\n"

        Params.stub(:[]).with('manual_file_changes').and_return(false)
        print "##### Monitor last time (standard) #####\n"
        # Third round monitoring with manual_file_changes as false but with file_attr_to_checksum
        dir_stat.monitor
        dir_stat.removed_unmarked_paths
        dir_stat.index

        # check that files were added to Dir
        files = dir_stat.instance_variable_get(:@files)
        print files
        print "\n"
        files.has_key?('temp_path/const_file').should be(true)
        files.has_key?('temp_path/will_be_deleted_file').should be(false)
        files.has_key?('temp_path/will_be_moved').should be(false)
        dirs = dir_stat.instance_variable_get(:@dirs)
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
