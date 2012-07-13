# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: Params test file.
# run: rake test.
# Note: This file will be tested along with all project tests.

require 'params'
require 'test/unit'
require_relative '../../lib/params.rb'

module BBFS

  class TestLog < Test::Unit::TestCase

    def test_parsing_of_the_defined_parameters
      #  Define options
      Params.integer('remote_server1', 3333,
                       'Listening port for backup server content data.')
      Params.string('backup_username1', 'tmp', 'Backup server username.')
      Params.string('backup_password1', 'tmp', 'Backup server password.')
      Params.string('backup_destination_folder1', '',
                       'Backup server destination folder, default is the relative local folder.')
      Params.string('content_data_path1', File.expand_path('~/.bbfs/var/content.data'),
                       'ContentData file path.')
      Params.string('monitoring_config_path1', File.expand_path('~/.bbfs/etc/file_monitoring.yml'),
                       'Configuration file for monitoring.')
      Params.float('time_to_start1', 0.03,
                             'Time to start monitoring')

      cmd = [ '--remote_server1=2222','--backup_username1=rami','--backup_password1=kavana',
             '--backup_destination_folder1=C:\Users\Alexey\Backup',
             '--content_data_path1=C:\Users\Alexey\Content',
             '--monitoring_config_path1=C:\Users\Alexey\Config',
             '--time_to_start1=1.5']
      Params.init cmd
      assert_equal(2222,Params['remote_server1'])
      assert_equal('rami',Params['backup_username1'])
      assert_equal('kavana',Params['backup_password1'])
      assert_equal('C:\Users\Alexey\Backup',Params['backup_destination_folder1'])
      assert_equal('C:\Users\Alexey\Content',Params['content_data_path1'])
      assert_equal('C:\Users\Alexey\Config',Params['monitoring_config_path1'])
      assert_equal(1.5,Params['time_to_start1'])
    end
  end
end

