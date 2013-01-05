# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains 'Params' module usage example.
# Run from bbfs> ruby -Ilib examples/params.rb
# Notes:
#   module.init should be called if user wants to override defined parameters by file or command line.
#   Parameter can be defined only once.
#   Parameters have to be defined before they are accessed. see examples below.

# Require:
require 'params'

# Examples of definitions:
Params.string 'parameter_str', 'this is a string' ,'description_for_string'
Params.integer 'parameter_int',1 , 'description_for_integer'
Params.float 'parameter_float',2.6 , 'description_for_float'
Params.boolean 'parameter_true', true, 'description_for_true'
Params.boolean 'parameter_false',false , 'description_for_false'
#   Note. Parameters have to be defined before they are accessed.

# Examples of usages (get\set access is through the [] operator).
# Good usages:
local_var_of_type_string = Params['parameter_str']
puts local_var_of_type_string  # Will produce --> this is a string
Params['parameter_float'] = 3.8  # Set defined parameter with new value through operator [].
puts Params['parameter_float']  # Will produce --> 3.8

#Bad usage:
# Only after definition, the [] operator will work. Else an error is raised.
begin
  Params['new_param'] = true  # will raise an error, since the param was not defined yet.
rescue Exception => e
  puts 'Code should reach here. An error was raised, since the param was not defined yet.'
  puts "Error message is:#{e.message}"
end

# Type check.
#   A type check is forced both when overriding with file or command line and in [] usage.
#   if parameter was defined as a Float using Params.float method (e.g. 2.6) and user
#   provided an integer when overriding or when using [] operator then the integer will
#   be casted to float.
#   Example 1: good usage. Casting example.
Params['parameter_float'] = 3  # The parameter is defined above.
puts "Params['parameter_float']=#{Params['parameter_float']} should produce --> 3.0 (note the casting)"

#   Example 2: Bad usage. Wrong type.
begin
  # The will raise an error, since the param type:'Float'
  # is different then the provided param type:'Boolean'.
  Params['parameter_float'] = true
rescue Exception => e
  puts "Code should reach here. An error was raised, since the param type:'Float' is " + \
       "different then the provided param type:'Boolean'."
  puts "Error message is:#{e.message}"
end

# Params.Init - override parameters.
#   implementation of the init sequence allows the override of
#   defined parameters with new values through input file and\or command line args.
#   Note that only defined parameters can be overridden. If new parameter is parsed
#   through file\command line, then an error will be raised.
#   Input config file override:
#     Default configuration input file path is: '~/.bbfs/conf/<executable name>.conf'
#     This path can be overridden by the command line arguments (see ahead).
#     If path and file exist then the parameters in the file will override the defined
#     parameters. File parameters format per line:<param_name>: <param value>
#     Note: Space char after the colon is mandatory
#   Command line arguments override:
#     General format per argument is:--<param_name>=<param_value>
#     those parameters will override the defined parameters and the file parameters.
#   Override input config file:
#     User can override the input file by using:--conf_file=<new_file_path>

# Example to override with command line:
# Run this file again using the following command line:
#   ruby -Ilib examples/params.rb --parameter_float=11.40
Params['parameter_float'] = 3.9
Params.init ARGV
puts "Params['parameter_float'] = #{Params['parameter_float']}"
# What is the result?
# if you have not used the command line argument: --parameter_float=11.40 then
# the result would be 3.9
# If you have used the argument --parameter_float=11.40 then
# the result would be 11.40. This is because 'Params.init ARGV' method has overridden the parameter.

# Example to override with file in the default file location:
# for this example. Pls put a file in the default location '~/.bbfs/conf/<executable name>.conf'
# with this line in it(inside the quotes):'parameter_int: 35'
# Run:  ruby -Ilib examples/params.rb
Params['parameter_int'] = 31
Params.init ARGV
puts "Params['parameter_int'] = #{Params['parameter_int']}"
# What is the result?
# if you have not used the file then the result would be 31
# If you have used the file then the result would be 35.
# This is because the parameter parameter_int was overridden by the file

# Example to override with file in a specified location:
# for this example. Pls put a file in any location you choose.
# For this example lat's say you have used: 'c:/my_input_file' path.
# Write this single line in it(inside the quotes):'parameter_true: true'
# Run:  ruby -Ilib examples/params.rb --conf_file=c:/my_input_file
Params['parameter_true'] = false
Params.init ARGV
puts "Params['parameter_true'] = #{Params['parameter_true']}"
# What is the result?
# if the file does not exist then the result would be false
# If the file exists then the result would be true.
# This is because the parameter parameter_int was overridden by the file

