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
      Params.parameter('remote_server', 'localhost', 'IP or DNS of backup server.')
      Params.parameter('remote_server', 3333,
                       'Listening port for backup server content data.')
      Params.parameter('backup_username', 'tmp', 'Backup server username.')
      Params.parameter('backup_password', 'tmp', 'Backup server password.')
      Params.parameter('backup_destination_folder', '',
                       'Backup server destination folder, default is the relative local folder.')
      Params.parameter('content_data_path', File.expand_path('~/.bbfs/var/content.data'),
                       'ContentData file path.')
      Params.parameter('monitoring_config_path', File.expand_path('~/.bbfs/etc/file_monitoring.yml'),
                       'Configuration file for monitoring.')
      Params.parameter('time_to_start', 0.03,
                             'Time to start monitoring')

      cmd = [ '--remote_server=2222','--backup_username=rami','--backup_password=kavana',
             '--backup_destination_folder=C:\Users\Alexey\Backup',
             '--content_data_path=C:\Users\Alexey\Content',
             '--monitoring_config_path=C:\Users\Alexey\Config',
             '--time_to_start=1.5']
      Params.parse_command_line_arguments(cmd)
      assert_equal(2222,Params.instance_variable_get('@remote_server'))
      assert_equal('rami',Params.instance_variable_get("@backup_username"))
      assert_equal('kavana',Params.instance_variable_get("@backup_password"))
      assert_equal('C:\Users\Alexey\Backup',Params.instance_variable_get("@backup_destination_folder"))
      assert_equal('C:\Users\Alexey\Content',Params.instance_variable_get("@content_data_path"))
      assert_equal('C:\Users\Alexey\Config',Params.instance_variable_get("@monitoring_config_path"))
      assert_equal(1.5,Params.instance_variable_get("@time_to_start"))
    end
  end
end

