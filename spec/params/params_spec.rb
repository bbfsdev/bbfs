# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains 'Param' module tests

# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'params'
end

require 'rspec'
require 'yaml'

require_relative '../../lib/params.rb'
require_relative '../../lib/content_server/server.rb'

module Params
  # make private methods or Params public for testing capability.
  public_class_method :parse_command_line_arguments, \
                      :raise_error_if_param_exists, :raise_error_if_param_does_not_exist, \
                      :read_yml_params, :override_param

  module Spec

    describe 'Params Test' do

      it 'test parsing of the defined parameters' do
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

        cmd = ['--remote_server1=2222', '--backup_username1=rami', '--backup_password1=kavana',
          '--backup_destination_folder1=C:\Users\Alexey\Backup',
          '--content_data_path1=C:\Users\Alexey\Content',
          '--monitoring_config_path1=C:\Users\Alexey\Config',
          '--time_to_start1=1.5']
        Params.init cmd
        Params['remote_server1'].should == 2222
        Params['backup_username1'].should == 'rami'
        Params['backup_password1'].should == 'kavana'
        Params['backup_destination_folder1'].should == 'C:\Users\Alexey\Backup'
        Params['content_data_path1'].should == 'C:\Users\Alexey\Content'
        Params['monitoring_config_path1'].should == 'C:\Users\Alexey\Config'
        Params['time_to_start1'].should == 1.5
      end
    end

    describe 'Params::parameter' do

      it 'should define a new parameters' do
        Params.string 'par_str', 'sss' ,'desc_str'
        Params.integer 'par_int',1 , 'desc_int'
        Params.float 'par_float',2.6 , 'desc_float'
        Params.boolean 'par_true', true, 'desc_true'
        Params.boolean 'par_false',false , 'desc_false'
        Params['par_str'].should eq 'sss'
        Params['par_int'].should eq 1
        Params['par_float'].should eq 2.6
        Params['par_true'].should eq true
        Params['par_false'].should eq false
      end

      it 'should raise an error for wrong parameter type definition.' do
        expect { Params::Param.new 'bad_type', 5, 'non_existing_type', 'desc_bad_type' }.to raise_error
      end

      it 'should raise an error when trying to define twice the same parameter' do
        Params.string 'only_once', '1st' ,''
        expect { Params.string 'only_once', '2nd' ,'' }.to raise_error \
              "Parameter:'only_once', can only be defined once."
      end
    end

    describe 'Params::read_yml_params' do
      # define dummy parameters for some tests below
      #Params.complex('monitoring_paths', [{'path'=>'', 'scan_period'=>0, 'stable_state'=>0}], '')
      #Params.complex('backup_destination_folder', [{''=>'path', 'scan_period'=>0, 'stable_state'=>0}], '')

      it 'should raise error when yml parameter is not defined' do
        expect { Params::read_yml_params StringIO.new 'not_defined: 10' }.to raise_error \
              "Parameter:'not_defined' has not been defined and can not be overridden. " \
              "It should first be defined through Param module methods:" \
              "Params.string, Params.path, Params.integer, Params.float, Params.complex, or Params.boolean."
      end

      it 'Will test yml parameter loading' do
        # string to other. Will not raise error. Instead a cast is made.
        Params.string('tmp4str', 'string_value', 'tmp4 def')
        expect { Params::read_yml_params StringIO.new 'tmp4str: strr' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4str: 4' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4str: 4.5' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4str: true' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4str: false' }.to_not raise_error

        # override integer with other types.
        Params.integer('tmp4int', 1, 'tmp4 def')
        expect { Params::read_yml_params StringIO.new 'tmp4int: strr' }.to raise_error \
          "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'String'."
        expect { Params::read_yml_params StringIO.new 'tmp4int: 4' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4int: 4.5' }.to raise_error \
              "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'Float'."
        expect { Params::read_yml_params StringIO.new 'tmp4int: true' }.to raise_error \
              "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'TrueClass'."
        expect { Params::read_yml_params StringIO.new 'tmp4int: false' }.to raise_error \
              "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'FalseClass'."

        # override float with other types.
        Params.float('tmp4float', 1.1, 'tmp4 def')
        expect { Params::read_yml_params StringIO.new 'tmp4float: strr' }.to raise_error \
          "Parameter:'tmp4float' type:'Float' but value type to override " \
                      "is:'String'."
        expect { Params::read_yml_params StringIO.new 'tmp4float: 4' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4float: 4.5' }.to_not raise_error
        expect { Params::read_yml_params StringIO.new 'tmp4float: true' }.to raise_error \
              "Parameter:'tmp4float' type:'Float' but value type to override " \
                      "is:'TrueClass'."
        expect { Params::read_yml_params StringIO.new 'tmp4float: false' }.to raise_error \
              "Parameter:'tmp4float' type:'Float' but value type to override " \
                      "is:'FalseClass'."
        # override boolean with other types.
        Params.boolean('tmp4true', true, 'tmp4 def')
        expect { Params::read_yml_params StringIO.new 'tmp4true: strr' }.to raise_error \
              "Parameter:'tmp4true' type:'Boolean' but value type to override " \
                      "is:'String'."
        expect { Params::read_yml_params StringIO.new 'tmp4true: 4' }.to raise_error \
              "Parameter:'tmp4true' type:'Boolean' but value type to override " \
                      "is:'Fixnum'."
        expect { Params::read_yml_params StringIO.new 'tmp4true: 4.5' }.to raise_error \
              "Parameter:'tmp4true' type:'Boolean' but value type to override " \
                      "is:'Float'."
        expect { Params::read_yml_params StringIO.new 'tmp4true: true' }.to_not raise_error
        expect { Params.read_yml_params StringIO.new 'tmp4true: false' }.to_not raise_error

        Params.boolean('tmp4False', true, 'tmp4 def')
        expect { Params.read_yml_params StringIO.new 'tmp4False: strr' }.to raise_error \
              "Parameter:'tmp4False' type:'Boolean' but value type to override " \
                      "is:'String'."
        expect { Params.read_yml_params StringIO.new 'tmp4False: 4' }.to raise_error \
              "Parameter:'tmp4False' type:'Boolean' but value type to override " \
                      "is:'Fixnum'."
        expect { Params.read_yml_params StringIO.new 'tmp4False: 4.5' }.to raise_error \
              "Parameter:'tmp4False' type:'Boolean' but value type to override " \
                      "is:'Float'."
        expect { Params.read_yml_params StringIO.new 'tmp4False: true' }.to_not raise_error
        expect { Params.read_yml_params StringIO.new 'tmp4False: false' }.to_not raise_error

      end

      it 'should return false when yml file format is bad' do
        Params.read_yml_params(StringIO.new 'bad yml format').should eq false
      end

      it 'should override defined values with yml values' do
        Params.string('tmp5str', 'aaa', 'tmp5 def')
        Params.integer('tmp5int', 11, 'tmp5 def')
        Params.float('tmp5float', 11.11, 'tmp5 def')
        Params.boolean('tmp5true', true, 'tmp5 def')
        Params.boolean('tmp5false', false, 'tmp5 def')
        Params.read_yml_params StringIO.new "tmp5str: bbb\ntmp5int: 12\ntmp5float: 12.12\n"
        Params.read_yml_params StringIO.new "tmp5true: false\ntmp5false: true\n"
        Params['tmp5str'].should eq 'bbb'
        Params['tmp5int'].should eq 12
        Params['tmp5float'].should eq 12.12
        Params['tmp5true'].should eq false
        Params['tmp5false'].should eq true
      end

      # If input is not Array we raise exception
      it 'should raise exception when monitoring_paths format is bad 1' do
        yml_bad_format="monitoring_paths: '~/.bbfs/backup_files'"
        expect {
          Params.read_yml_params(StringIO.new(yml_bad_format))
          check_monitoring_path_structure('monitoring_paths', 1)
        }.to raise_error
      end

      # expecting 1 path for backup_destination_folder
      # (in call to check_monitoring_path_structure) but user gives
      # 2 paths.
      it 'should raise exception when backup_destination_folder format is bad 2' do
        yml_bad_format=<<EOF
backup_destination_folder:
  - path: 'some_path_1
    scan_period: 200
    stable_state: 2
  - path: 'some_path_2
    scan_period: 200
    stable_state: 2
EOF
        puts "yml_bad_format type=\n#{yml_bad_format.class}\n#{yml_bad_format}"
        expect {
          Params.read_yml_params(StringIO.new(yml_bad_format.to_s))
          check_monitoring_path_structure('backup_destination_folder', 1)
        }.to raise_error
      end

      # missing 'stable_state' in hash
      it 'should raise exception when monitoring_paths format is bad 3' do
        yml_bad_format=<<EOF
monitoring_paths:
  - path: 'some_path
    scan_period: 200
EOF
        puts "yml_bad_format=\n#{yml_bad_format}\n"
        expect {
          Params.read_yml_params(StringIO.new(yml_bad_format.to_s))
          check_monitoring_path_structure('monitoring_paths', 1)
        }.to raise_error
      end

      it 'should not raise exception when monitoring_paths format is good - paths size is 1)' do
        yml_good_format=<<EOF
monitoring_paths:
  - path: 'some_path
    scan_period: 200
    stable_state: 2
EOF
        puts "yml_good_format=\n#{yml_good_format}\n"
        expect {
          Params.read_yml_params(StringIO.new(yml_good_format.to_s))
          check_monitoring_path_structure('monitoring_paths', 1)
        }.to_not raise_error
      end

      it 'should not raise exception when monitoring_paths format is good - any paths size' do
        yml_good_format=<<EOF
monitoring_paths:
  - path: 'some_path_1
    scan_period: 200
    stable_state: 2
  - path: 'some_path_2
    scan_period: 200
    stable_state: 2
EOF
        puts "yml_good_format=\n#{yml_good_format}\n"
        expect {
          Params.read_yml_params(StringIO.new(yml_good_format.to_s))
          check_monitoring_path_structure('monitoring_paths', 0)
        }.to_not raise_error
      end
    end

    describe 'Params.parse_command_line_arguments' do
      it 'should raise error when command line parameter is not defined' do
        expect { Params.parse_command_line_arguments ['--new_param=9]'] }.to raise_error
      end

      it 'should parse parameter from command line.' do
        # Override string with types.
        Params.string('tmp6str', 'dummy', 'tmp6str def')
        expect { Params.parse_command_line_arguments ['--tmp6str=9'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp6str=8.1'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp6str=ff'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp6str=true'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp6str=false'] }.to_not raise_error

        # from fixnum to other types.
        Params.integer('tmp6', 8, 'tmp6 def')
        expect { Params.parse_command_line_arguments ['--tmp6=9'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp6=8.1'] }.to raise_error
        expect { Params.parse_command_line_arguments ['--tmp6=ff'] }.to raise_error
        expect { Params.parse_command_line_arguments ['--tmp6=true'] }.to raise_error
        expect { Params.parse_command_line_arguments ['--tmp6=false'] }.to raise_error

        # from float to other types.
        Params.float('tmp7', 8.9, 'tmp7 def')
        # Casting fix num to float
        expect { Params.parse_command_line_arguments ['--tmp7=9'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp7=3.4'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp7=ff'] }.to raise_error
        expect { Params.parse_command_line_arguments ['--tmp7=true'] }.to raise_error
        expect { Params.parse_command_line_arguments ['--tmp7=false'] }.to raise_error

        # from TrueClass to other types.
        Params.boolean('tmp8', true, 'tmp8 def')
        expect { Params.parse_command_line_arguments ['--tmp8=9'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp8=3.4'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp8=ff'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp8=true'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp8=false'] }.to_not raise_error

        # from FalseClass to other types.
        Params.boolean('tmp9', false, 'tmp9 def')
        expect { Params.parse_command_line_arguments ['--tmp9=9'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp9=3.4'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp9=ff'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp9=true'] }.to_not raise_error
        expect { Params.parse_command_line_arguments ['--tmp9=false'] }.to_not raise_error
      end
    end

    describe 'Params.init' do
      it 'should override command line arguments correctly.' do
        File.stub(:exist?).and_return false
        # Override string with types.
        Params.string('tmp6str2', 'dummy', 'tmp6str def')
        expect { Params.init ['--tmp6str2=9'] }.to_not raise_error
        expect { Params.init ['--tmp6str2=8.1'] }.to_not raise_error
        expect { Params.init ['--tmp6str2=ff'] }.to_not raise_error
        expect { Params.init ['--tmp6str2=true'] }.to_not raise_error
        expect { Params.init ['--tmp6str2=false'] }.to_not raise_error

        # from fixnum to other types.
        Params.integer('tmp6Fixnum2', 8, 'tmp6 def')
        expect { Params.init ['--tmp6Fixnum2=9'] }.to_not raise_error
        expect { Params.init ['--tmp6Fixnum2=8.1'] }.to raise_error
        expect { Params.init ['--tmp6Fixnum2=ff'] }.to raise_error
        expect { Params.init ['--tmp6Fixnum2=true'] }.to raise_error
        expect { Params.init ['--tmp6Fixnum2=false'] }.to raise_error

        # from float to other types.
        Params.float('tmp7float2', 8.9, 'tmp7 def')
        # Casting fix num to float
        expect { Params.init ['--tmp7float2=9'] }.to_not raise_error
        expect { Params.init ['--tmp7float2=3.4'] }.to_not raise_error
        expect { Params.init ['--tmp7float2=ff'] }.to raise_error
        expect { Params.init ['--tmp7float2=true'] }.to raise_error
        expect { Params.init ['--tmp7float2=false'] }.to raise_error

        # from TrueClass to other types.
        Params.boolean('tmp8true2', true, 'tmp8 def')
        expect { Params.init ['--tmp8true2=9'] }.to raise_error
        expect { Params.init ['--tmp8true2=3.4'] }.to raise_error
        expect { Params.init ['--tmp8true2=ff'] }.to raise_error
        expect { Params.init ['--tmp8true2=true'] }.to_not raise_error
        expect { Params.init ['--tmp8true2=false'] }.to_not raise_error

        # from FalseClass to other types.
        Params.boolean('tmp9false2', false, 'tmp9 def')
        expect { Params.init ['--tmp9false2=9'] }.to raise_error
        expect { Params.init ['--tmp9false2=3.4'] }.to raise_error
        expect { Params.init ['--tmp9false2=ff'] }.to raise_error
        expect { Params.init ['--tmp9false2=true'] }.to_not raise_error
        expect { Params.init ['--tmp9false2=false'] }.to_not raise_error
      end

      it 'should override defined values with command line values' do
        File.stub(:exist?).and_return false
        Params.string('tmp10str', 'aaa', 'tmp10 def')
        Params.integer('tmp10int', 11, 'tmp10 def')
        Params.float('tmp10float', 11.11, 'tmp10 def')
        Params.boolean('tmp10true', true, 'tmp10 def')
        Params.boolean('tmp10false', false, 'tmp10 def')
        Params.init ['--tmp10str=bbb', '--tmp10int=12', '--tmp10float=12.12', \
                       '--tmp10true=false', '--tmp10false=true']
        Params['tmp10str'].should eq 'bbb'
        Params['tmp10int'].should eq 12
        Params['tmp10float'].should eq 12.12
        Params['tmp10true'].should eq false
        Params['tmp10false'].should eq true
      end

      it 'init should override parameters with file and command' do
        Params.string('init_param', 'code', '')
        File.stub(:exist?).and_return true
        File.stub(:open).and_return StringIO.new 'init_param: yml'
        Params.init ['--conf_file=dummy_file', '--init_param=command-line']
        Params['init_param'].should eq 'command-line'
      end

      it 'init should override parameters with file only' do
        Params.string('init_param2', 'code', '')
        File.stub(:exist?).and_return true
        File.stub(:open).and_return StringIO.new 'init_param2: yml'
        Params.init ['--conf_file=dummy_file']
        Params['init_param2'].should eq 'yml'
      end

      it 'init should override parameters with command line only' do
        Params.string('init_param3', 'code', '')
        File.stub(:exist?).and_return false
        Params.init ['--init_param3=command-line']
        Params['init_param3'].should eq 'command-line'
      end

      it 'init should not override any parameters' do
        Params.string('init_param4', 'code', '')
        File.stub(:exist?).and_return false
        Params.init []
        Params['init_param4'].should eq 'code'
      end
    end
  end
end

