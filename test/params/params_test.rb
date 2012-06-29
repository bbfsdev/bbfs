# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: Params test file.
# run: rake test.
# Note: This file will be tested along with all project tests.

require 'params'
require 'test/unit'
require_relative '../../lib/params.rb'

module BBFS

  class TestLog < Test::Unit::TestCase
    def test_override_predefined_param_with_loaded_yml_param
      # Test set phase
      code_param_name =  'param_1'
      code_param_value = 'value_1_code'
      yml_string = 'param_1: value_1_yml'
      yml_param_value = 'value_1_yml'
      #define a new param
      Params.parameter code_param_name, code_param_value , 'Defined at test code'

      # Test check phase
      # 1. Check that param_1 was defined correctly at Params
      assert_equal code_param_value, Params.param_1 , 'Abnormal behaviour. "Params" module does not work'
      #read params from yml file. This should override the param value
      Params.read_yml_params(yml_string)
      # 2. Check that param_1 value was overridden by the yml param
      assert_equal yml_param_value, Params.param_1 , "parameter:[#{code_param_name}] " + \
        "was defined both at the test code with value:[#{code_param_value}], " + \
        "and at the yml string [#{yml_string}] with value:[#{yml_param_value}]. " \
        "The test expected the yml file value to overwrite the code value but it did not."
    end

    def test_yml_loads_an_undefined_param
      assert_equal false, Params.read_yml_params('param_2: value_2_yml') , \
        'Error. yml param should not have been defined in Params'
    end

    def test_parsing_of_the_defined_parameters
      #  Define options
      Params.parameter('remote_server', 'localhost', 'IP or DNS of backup server.')
      Params.parameter('remote_server', 3333,
                       'Listening port for backup server content data.')
      Params.parameter('backup_username', nil, 'Backup server username.')
      Params.parameter('backup_password', nil, 'Backup server password.')
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
      x = Params.parse(cmd)
      assert_equal(2222,Params.instance_variable_get('@remote_server'))
      assert_equal('rami',Params.instance_variable_get("@backup_username"))
      assert_equal('kavana',Params.instance_variable_get("@backup_password"))
      assert_equal('C:\Users\Alexey\Backup',Params.instance_variable_get("@backup_destination_folder"))
      assert_equal('C:\Users\Alexey\Content',Params.instance_variable_get("@content_data_path"))
      assert_equal('C:\Users\Alexey\Config',Params.instance_variable_get("@monitoring_config_path"))
      assert_equal(1.5,Params.instance_variable_get("@time_to_start"))
      puts x
      puts Params.instance_variables

    end
  end
end

