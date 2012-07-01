require 'rspec'
require 'yaml'

require_relative '../../lib/params.rb'

module BBFS
  module Params
    module Spec
      describe 'Params::parameter' do
        it 'should raise error when parameter is defined as nil' do
          Params.params_initialized = false
          expect { Params::parameter('tmp', nil, 'tmp nil def') }.should raise_error \
              "parameter:'tmp' value can not be nil."
        end

        it 'should define a new parameter' do
          Params.params_initialized = false
          Params.parameter 'tmp', 1, 'tmp'
          Params.tmp.should eq 1
        end

        it 'should raise an error when trying to define parameter after init phase' do
          Params.params_initialized = true
          expect { Params::parameter('tmp2', 'dummy', 'tmp2 not ok') }.should raise_error \
              "parameters already initialized. No new definitions are allowed."
        end
      end

      describe 'Params::read_yml_params' do
        it 'should raise error when yml parameter is not defined' do
          Params.params_initialized = false
          expect { Params::read_yml_params StringIO.new 'tmp3: 3' }.should raise_error \
              "loaded yml param:'tmp3' which does not exist in Params module."
        end

        it 'should raise error when yml parameter type is different then definition' do
          Params.params_initialized = false
          # string to other
          Params::parameter('tmp4str', 'string_value', 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4str: strr' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4str: 4' }.should raise_error \
              "loaded yml param:'tmp4str' has different value type:'Fixnum'" + \
                " then the defined parameter type:'String'"
          expect { Params::read_yml_params StringIO.new 'tmp4str: 4.5' }.should raise_error \
              "loaded yml param:'tmp4str' has different value type:'Float'" + \
                " then the defined parameter type:'String'"
          expect { Params::read_yml_params StringIO.new 'tmp4str: true' }.should raise_error \
              "loaded yml param:'tmp4str' has different value type:'TrueClass'" + \
                " then the defined parameter type:'String'"
          expect { Params::read_yml_params StringIO.new 'tmp4str: false' }.should raise_error \
              "loaded yml param:'tmp4str' has different value type:'FalseClass'" + \
                " then the defined parameter type:'String'"

          # integer to other
          Params::parameter('tmp4int', 1, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4int: strr' }.should raise_error \
          "loaded yml param:'tmp4int' has different value type:'String'" + \
                " then the defined parameter type:'Fixnum'"
          expect { Params::read_yml_params StringIO.new 'tmp4int: 4' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4int: 4.5' }.should raise_error \
              "loaded yml param:'tmp4int' has different value type:'Float'" + \
                " then the defined parameter type:'Fixnum'"
          expect { Params::read_yml_params StringIO.new 'tmp4int: true' }.should raise_error \
              "loaded yml param:'tmp4int' has different value type:'TrueClass'" + \
                " then the defined parameter type:'Fixnum'"
          expect { Params::read_yml_params StringIO.new 'tmp4int: false' }.should raise_error \
              "loaded yml param:'tmp4int' has different value type:'FalseClass'" + \
                " then the defined parameter type:'Fixnum'"

          # float to other
          Params::parameter('tmp4float', 1.1, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4float: strr' }.should raise_error \
          "loaded yml param:'tmp4float' has different value type:'String'" + \
                " then the defined parameter type:'Float'"
          expect { Params::read_yml_params StringIO.new 'tmp4float: 4' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4float: 4.5' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4float: true' }.should raise_error \
              "loaded yml param:'tmp4float' has different value type:'TrueClass'" + \
                " then the defined parameter type:'Float'"
          expect { Params::read_yml_params StringIO.new 'tmp4float: false' }.should raise_error \
              "loaded yml param:'tmp4float' has different value type:'FalseClass'" + \
                " then the defined parameter type:'Float'"
          # true to other
          Params::parameter('tmp4true', true, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4true: strr' }.should raise_error \
              "loaded yml param:'tmp4true' has different value type:'String'" + \
                " then the defined parameter type:'TrueClass'"
          expect { Params::read_yml_params StringIO.new 'tmp4true: 4' }.should raise_error \
              "loaded yml param:'tmp4true' has different value type:'Fixnum'" + \
                " then the defined parameter type:'TrueClass'"
          expect { Params::read_yml_params StringIO.new 'tmp4true: 4.5' }.should raise_error \
              "loaded yml param:'tmp4true' has different value type:'Float'" + \
                " then the defined parameter type:'TrueClass'"
          expect { Params::read_yml_params StringIO.new 'tmp4true: true' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4true: false' }.should_not raise_error

          # false to other
          Params::parameter('tmp4false', false, 'tmp4 def')
          expect { Params::read_yml_params StringIO.new 'tmp4false: strr' }.should raise_error \
              "loaded yml param:'tmp4false' has different value type:'String'" + \
                " then the defined parameter type:'FalseClass'"
          expect { Params::read_yml_params StringIO.new 'tmp4false: 4' }.should raise_error \
              "loaded yml param:'tmp4false' has different value type:'Fixnum'" + \
                " then the defined parameter type:'FalseClass'"
          expect { Params::read_yml_params StringIO.new 'tmp4false: 4.5' }.should raise_error \
              "loaded yml param:'tmp4false' has different value type:'Float'" + \
                " then the defined parameter type:'FalseClass'"
          expect { Params::read_yml_params StringIO.new 'tmp4false: true' }.should_not raise_error
          expect { Params::read_yml_params StringIO.new 'tmp4false: false' }.should_not raise_error
        end

        it 'should raise error when yml file format is bad' do
          Params.params_initialized = false
          expect { Params::read_yml_params StringIO.new 'bad yml format' }.should raise_error
        end

        it 'should override defined values with yml value' do
          Params.params_initialized = false
          Params::parameter('tmp5str', 'aaa', 'tmp5 def')
          Params::parameter('tmp5int', 11, 'tmp5 def')
          Params::parameter('tmp5float', 11.11, 'tmp5 def')
          Params::parameter('tmp5true', true, 'tmp5 def')
          Params::parameter('tmp5false', false, 'tmp5 def')
          Params::read_yml_params StringIO.new "tmp5str: bbb\ntmp5int: 12\ntmp5float: 12.12\n"
          Params::read_yml_params StringIO.new "tmp5true: false\ntmp5false: true\n"
          Params.tmp5str.should eq 'bbb'
          Params.tmp5int.should eq 12
          Params.tmp5float.should eq 12.12
          Params.tmp5true.should eq false
          Params.tmp5false.should eq true
        end
      end

      describe 'Params::parse_command_line_arguments' do
        it 'should raise error when command line parameter is not defined' do
          Params.params_initialized = false
          expect { Params::parse_command_line_arguments ['--new_param=9]'] }.should raise_error
        end

        it 'should raise error when command line parameter type is different then definition' do
          Params.params_initialized = false

          # from str to other types.
          Params::parameter('tmp6str', 'dummy', 'tmp6str def')
          expect { Params::parse_command_line_arguments ['--tmp6str=9'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp6str=8.1'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp6str=ff'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp6str=true'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp6str=false'] }.should_not raise_error

          # from fixnum to other types.
          Params::parameter('tmp6', 8, 'tmp6 def')
          expect { Params::parse_command_line_arguments ['--tmp6=9'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp6=8.1'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp6=ff'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp6=true'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp6=false'] }.should raise_error

          # from float to other types.
          Params::parameter('tmp7', 8.9, 'tmp7 def')
          # Casting fix num to float
          expect { Params::parse_command_line_arguments ['--tmp7=9'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp7=3.4'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp7=ff'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp7=true'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp7=false'] }.should raise_error

          # from TrueClass to other types.
          Params::parameter('tmp8', true, 'tmp8 def')
          expect { Params::parse_command_line_arguments ['--tmp8=9'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp8=3.4'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp8=ff'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp8=true'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp8=false'] }.should_not raise_error

          # from FalseClass to other types.
          Params::parameter('tmp9', false, 'tmp9 def')
          expect { Params::parse_command_line_arguments ['--tmp9=9'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp9=3.4'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp9=ff'] }.should raise_error
          expect { Params::parse_command_line_arguments ['--tmp9=true'] }.should_not raise_error
          expect { Params::parse_command_line_arguments ['--tmp9=false'] }.should_not raise_error
        end

        it 'should override defined values with command line values' do
          Params.params_initialized = false
          Params::parameter('tmp10str', 'aaa', 'tmp10 def')
          Params::parameter('tmp10int', 11, 'tmp10 def')
          Params::parameter('tmp10float', 11.11, 'tmp10 def')
          Params::parameter('tmp10true', true, 'tmp10 def')
          Params::parameter('tmp10false', false, 'tmp10 def')
          Params::parse_command_line_arguments ['--tmp10str=bbb', '--tmp10int=12', '--tmp10float=12.12']
          Params::parse_command_line_arguments ['--tmp10true=false', '--tmp10false=true']
          Params.tmp10str.should eq 'bbb'
          Params.tmp10int.should eq 12
          Params.tmp10float.should eq 12.12
          Params.tmp10true.should eq false
          Params.tmp10false.should eq true
        end
      end

      describe 'Params::init' do
        it 'init should override parameters with file and command' do
          Params.params_initialized = false
          Params::parameter('init_param', 'code', '')
          File.stub(:exist?).and_return true
          File.stub(:open).and_return StringIO.new 'init_param: yml'
          Params.init ['--conf_file=dummy_file', '--init_param=command-line']
          Params.init_param.should eq 'command-line'
        end

        it 'init should override parameters with file only' do
          Params.params_initialized = false
          Params::parameter('init_param', 'code', '')
          File.stub(:exist?).and_return true
          File.stub(:open).and_return StringIO.new 'init_param: yml'
          Params.init ['--conf_file=dummy_file']
          Params.init_param.should eq 'yml'
        end

        it 'init should override parameters with command line only' do
          Params.params_initialized = false
          Params::parameter('init_param', 'code', '')
          File.stub(:exist?).and_return false
          Params.init ['--init_param=command-line']
          Params.init_param.should eq 'command-line'
        end

        it 'init should not override any parameters' do
          Params.params_initialized = false
          Params::parameter('init_param', 'code', '')
          File.stub(:exist?).and_return false
          Params.init []
          Params.init_param.should eq 'code'
        end

        it 'init should raise error when defining new param after init' do
          Params.params_initialized = false
          File.stub(:exist?).and_return false
          Params.init []
          expect { Params::parameter('bad_param', 'can not define after init', '') }.should raise_error \
                    "parameters already initialized. No new definitions are allowed."
        end
      end
    end
  end
end

