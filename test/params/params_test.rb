# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: Params test file.
# run: rake test.
# Note: This file will be tested along with all project tests.

require 'params'
require 'test/unit'
require_relative '../../lib/params.rb'

module BBFS

  class TestLog < Test::Unit::TestCase

    def test_define_both_code_and_yml_params
      # Test set phase
      code_param_name =  'param_1'
      code_param_value = 'value_defined_at_test_code'
      code_param_desc =  'Defined at test code'
      yml_param_value = 'value_defined_at_yml_file'
      yml_file_name = 'test/params/test_1.yml'
      #define param in the code
      Params.parameter code_param_name, code_param_value , code_param_desc

      # Test check phase
      # First check the param_1 was defined correctly at Params
      assert_equal code_param_value, Params.param_1 , 'Abnormal behaviour. "Params" module does not work'
      #read params from yml file. This should override the param value
      Params.read_from_yml(File.expand_path(yml_file_name))
      # Now check that param_1 value was overriden by the yml file params
      assert_equal yml_param_value, Params.param_1 , "parameter:[#{code_param_name}] " + \
      "was defined both at the test code with value:[#{code_param_value}], " + \
      "and at the yml file:#{yml_file_name} with value:[#{yml_param_value}]. " \
      "The test expected the yml file value to overwrite the code value but it did not."
    end
  end
end

