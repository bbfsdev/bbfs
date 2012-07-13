# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains 'Param' module tests

require 'rspec'
require 'yaml'

require_relative '../../lib/params.rb'

module BBFS
  module Params
    module Spec
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
          expect { Params::Param.new 'bad_type', nil, 'non_existing_type', 'desc_bad_type' }.should raise_error
        end

        it 'should raise an error when trying to define twice the same parameter' do
          Params.string 'only_once', '1st' ,''
          expect { Params.string 'only_once', '2nd' ,'' }.should raise_error \
              "Parameter:'only_once', can only be defined oncet."
        end
      end

      describe 'Params::read_yml_params' do
        it 'should raise error when yml parameter is not defined' do
          expect { Params::read_yml_params StringIO.new 'not_defined: 10' }.should raise_error \
              "Parameter:'not_defined' has not been defined and can not be overridden. " \
              "It should first be defined through Param module methods:" \
              "Params.string, Params.integer, Params.float or Params.boolean."
        end

        it 'Will test yml parameter loading' do
          # string to other. Will not raise error. Instead a cast is made.
          Params.string('tmp4str', 'string_value', 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4str: strr' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4str: 4' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4str: 4.5' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4str: true' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4str: false' }.should_not raise_error

          # override integer with other types.
          Params.integer('tmp4int', 1, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4int: strr' }.should raise_error \
          "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'String'."
          expect { Params::read_yml_params StringIO.new 'tmp4int: 4' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4int: 4.5' }.should raise_error \
              "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'Float'."
          expect { Params::read_yml_params StringIO.new 'tmp4int: true' }.should raise_error \
              "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'TrueClass'."
          expect { Params::read_yml_params StringIO.new 'tmp4int: false' }.should raise_error \
              "Parameter:'tmp4int' type:'Integer' but value type to override " \
                      "is:'FalseClass'."

          # override float with other types.
          Params.float('tmp4float', 1.1, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4float: strr' }.should raise_error \
          "Parameter:'tmp4float' type:'Float' but value type to override " \
                      "is:'String'."
          expect { Params::read_yml_params StringIO.new 'tmp4float: 4' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4float: 4.5' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4float: true' }.should raise_error \
              "Parameter:'tmp4float' type:'Float' but value type to override " \
                      "is:'TrueClass'."
          expect { Params::read_yml_params StringIO.new 'tmp4float: false' }.should raise_error \
              "Parameter:'tmp4float' type:'Float' but value type to override " \
                      "is:'FalseClass'."
          # override boolean with other types.
          Params.boolean('tmp4true', true, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4true: strr' }.should raise_error \
              "Parameter:'tmp4true' type:'Boolean' but value type to override " \
                      "is:'String'."
          expect { Params::read_yml_params StringIO.new 'tmp4true: 4' }.should raise_error \
              "Parameter:'tmp4true' type:'Boolean' but value type to override " \
                      "is:'Fixnum'."
          expect { Params::read_yml_params StringIO.new 'tmp4true: 4.5' }.should raise_error \
              "Parameter:'tmp4true' type:'Boolean' but value type to override " \
                      "is:'Float'."
          expect { Params::read_yml_params StringIO.new 'tmp4true: true' }.should_not raise_error
          expect { Params.read_yml_params StringIO.new 'tmp4true: false' }.should_not raise_error

          Params.boolean('tmp4False', true, 'tmp4 def')
          expect { Params.read_yml_params StringIO.new 'tmp4False: strr' }.should raise_error \
              "Parameter:'tmp4False' type:'Boolean' but value type to override " \
                      "is:'String'."
          expect { Params.read_yml_params StringIO.new 'tmp4False: 4' }.should raise_error \
              "Parameter:'tmp4False' type:'Boolean' but value type to override " \
                      "is:'Fixnum'."
          expect { Params.read_yml_params StringIO.new 'tmp4False: 4.5' }.should raise_error \
              "Parameter:'tmp4False' type:'Boolean' but value type to override " \
                      "is:'Float'."
          expect { Params.read_yml_params StringIO.new 'tmp4False: true' }.should_not raise_error
          expect { Params.read_yml_params StringIO.new 'tmp4False: false' }.should_not raise_error

        end

        it 'should raise error when yml file format is bad' do
          expect { Params.read_yml_params StringIO.new 'bad yml format' }.should raise_error
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
      end

      describe 'Params.parse_command_line_arguments' do
        it 'should raise error when command line parameter is not defined' do
          expect { Params.parse_command_line_arguments ['--new_param=9]'] }.should raise_error
        end

        it 'should parse parameter from command line.' do
          # Override string with types.
          Params.string('tmp6str', 'dummy', 'tmp6str def')
          expect { Params.parse_command_line_arguments ['--tmp6str=9'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp6str=8.1'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp6str=ff'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp6str=true'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp6str=false'] }.should_not raise_error

          # from fixnum to other types.
          Params.integer('tmp6', 8, 'tmp6 def')
          expect { Params.parse_command_line_arguments ['--tmp6=9'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp6=8.1'] }.should raise_error
          expect { Params.parse_command_line_arguments ['--tmp6=ff'] }.should raise_error
          expect { Params.parse_command_line_arguments ['--tmp6=true'] }.should raise_error
          expect { Params.parse_command_line_arguments ['--tmp6=false'] }.should raise_error

          # from float to other types.
          Params.float('tmp7', 8.9, 'tmp7 def')
          # Casting fix num to float
          expect { Params.parse_command_line_arguments ['--tmp7=9'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp7=3.4'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp7=ff'] }.should raise_error
          expect { Params.parse_command_line_arguments ['--tmp7=true'] }.should raise_error
          expect { Params.parse_command_line_arguments ['--tmp7=false'] }.should raise_error

          # from TrueClass to other types.
          Params.boolean('tmp8', true, 'tmp8 def')
          expect { Params.parse_command_line_arguments ['--tmp8=9'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp8=3.4'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp8=ff'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp8=true'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp8=false'] }.should_not raise_error

          # from FalseClass to other types.
          Params.boolean('tmp9', false, 'tmp9 def')
          expect { Params.parse_command_line_arguments ['--tmp9=9'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp9=3.4'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp9=ff'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp9=true'] }.should_not raise_error
          expect { Params.parse_command_line_arguments ['--tmp9=false'] }.should_not raise_error
        end
      end

      describe 'Params.init' do
        it 'should override command line arguments correctly.' do
          File.stub(:exist?).and_return false
          # Override string with types.
          Params.string('tmp6str2', 'dummy', 'tmp6str def')
          expect { Params.init ['--tmp6str2=9'] }.should_not raise_error
          expect { Params.init ['--tmp6str2=8.1'] }.should_not raise_error
          expect { Params.init ['--tmp6str2=ff'] }.should_not raise_error
          expect { Params.init ['--tmp6str2=true'] }.should_not raise_error
          expect { Params.init ['--tmp6str2=false'] }.should_not raise_error

          # from fixnum to other types.
          Params.integer('tmp6Fixnum2', 8, 'tmp6 def')
          expect { Params.init ['--tmp6Fixnum2=9'] }.should_not raise_error
          expect { Params.init ['--tmp6Fixnum2=8.1'] }.should raise_error
          expect { Params.init ['--tmp6Fixnum2=ff'] }.should raise_error
          expect { Params.init ['--tmp6Fixnum2=true'] }.should raise_error
          expect { Params.init ['--tmp6Fixnum2=false'] }.should raise_error

          # from float to other types.
          Params.float('tmp7float2', 8.9, 'tmp7 def')
          # Casting fix num to float
          expect { Params.init ['--tmp7float2=9'] }.should_not raise_error
          expect { Params.init ['--tmp7float2=3.4'] }.should_not raise_error
          expect { Params.init ['--tmp7float2=ff'] }.should raise_error
          expect { Params.init ['--tmp7float2=true'] }.should raise_error
          expect { Params.init ['--tmp7float2=false'] }.should raise_error

          # from TrueClass to other types.
          Params.boolean('tmp8true2', true, 'tmp8 def')
          expect { Params.init ['--tmp8true2=9'] }.should raise_error
          expect { Params.init ['--tmp8true2=3.4'] }.should raise_error
          expect { Params.init ['--tmp8true2=ff'] }.should raise_error
          expect { Params.init ['--tmp8true2=true'] }.should_not raise_error
          expect { Params.init ['--tmp8true2=false'] }.should_not raise_error

          # from FalseClass to other types.
          Params.boolean('tmp9false2', false, 'tmp9 def')
          expect { Params.init ['--tmp9false2=9'] }.should raise_error
          expect { Params.init ['--tmp9false2=3.4'] }.should raise_error
          expect { Params.init ['--tmp9false2=ff'] }.should raise_error
          expect { Params.init ['--tmp9false2=true'] }.should_not raise_error
          expect { Params.init ['--tmp9false2=false'] }.should_not raise_error
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
end

