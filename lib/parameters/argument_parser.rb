require 'optparse'

#Interface (not final):
#add_flag(command_name, flag_name, flag_type, flag_default_value, flag_description) // adds flag configuration to argument parser module.
#parse(argv) // validates arguments and store command and flags values.
#get_value(flag_name) // returns the value of flag_name, if values was not provided return the default value, if no default value, output error.
#get_command() // returns the command (first string in the argv array)

class ArgumentParser

  def initialize
    @m_flags = Hash.new("Initializing") #define flags hash
    @flags_values = Hash.new("Initializing") #define flags values hash
  end

  def add_flag(command_name, flag_name, flag_type, flag_default_value, flag_description )

    if (@m_flags.has_key?(command_name) == false )
      @m_flags[command_name]  =  Hash.new            # store required command
    end

    if (@m_flags[command_name].has_key?(flag_name) == false )
      @m_flags[command_name][flag_name]   =  Hash.new            # store values for the type
    end

    @m_flags[command_name][flag_name]['flag_type'] = flag_type  # store flag type
    @m_flags[command_name][flag_name]['flag_value'] = flag_default_value  # store default value
    @m_flags[command_name][flag_name]['flag_description'] = flag_description  # store flag description

    return true
  end

  #Function parse (cmd_line )
  # validates arguments and stored commands and flags values
  def parse (argv)
    check_cmd = argv.split(" ")# split the line into string
     #Run thru string and parse
    check_cmd.each  do  |str|
      if (str == nil)
        break
      end
    end
  end


  def get_command()
    return @m_flags.keys
    return true
  end

  def get_flag_value(command, flag_name)
    if (@m_flags.has_key?(command) == true )
      if (@m_flags[command].has_key?(flag_name) == true )
        return  @m_flags[command][flag_name]['flag_value']
      end
    end
    return false
  end
end
