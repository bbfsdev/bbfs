#!/usr/bin/ruby

# This file is the basic file manipulation tool for the distributed system.
# All the basic commands should reside here.

require './content_data.rb'

class FileUtil
  def initialize(arguments)
    if arguments["command"] == "mksymlink"
      begin
        puts "--ref_cd is not set"
        return
      end unless not arguments["ref_cd"].nil?
      ref_cd = ContentData.new()
      ref_cd.from_file(arguments["ref_cd"])
      begin
        puts "Error loading content data ref_cd=%s" % arguments["ref_cd"]
        return
      end unless not ref_cd.nil?

      begin
        puts "--base_cd is not set"
        return
      end unless not arguments["base_cd"].nil?
      base_cd = ContentData.new()
      base_cd.from_file(arguments["base_cd"])
      begin
        puts "Error loading content data base_cd=%s" % arguments["base_cd"]
        return
      end unless not base_cd.nil?

      begin
        puts "--dest is not set"
        return
      end unless not arguments["dest"].nil?

      output = FileUtil.mksymlink(ref_cd, base_cd, arguments["dest"])
      commands = output[0]
      commands.sort!
      puts "Commands to create symlink:"
      commands.each{ |command|
        puts command
      }

      warnings = output[1]
      warnings.sort!
      puts "Warnings:"
      warnings.each{ |warning|
        puts warning
      }
      if warnings.length == 0
        puts "None."
      end

    end
  end

  def self.mksymlink(ref_cd, base_cd, dest)
    #begin
    #  Dir.mkdir dest unless Dir.exists? dest
    #rescue SystemCallError => e
    #  puts e
    #  return false
    #end

    inverted_index = Hash.new

    base_cd.instances.values.each{ |instance|
      inverted_index[instance.checksum] = instance
    }

    commands = Array.new
    warnings = Array.new

    ref_cd.instances.values.each { |instance|
      if inverted_index.key? instance.checksum
        commands << "%s => %s%s" % [instance.global_path, dest, inverted_index[instance.checksum].global_path]
      else
        warnings << "Warning: base content does not contains:'%s'" % instance.checksum
      end
    }

    return [commands, warnings]
  end
end

COMMANDS = Hash.new
COMMANDS["mksymlink"] = "  mksymlink --ref_cd=<path> --base_cd=<path> --dest=<path>"

def print_usage
    puts "Usage: fileutil <command> parameters..."
    puts "Commands:"
    COMMANDS.each { |name, description|
      puts description
    }
end

def read_arguments(argv, parsed_arguments)
  argv.each { |arg|
    if arg.start_with?("--")
      words = arg[2,arg.length-2].split('=')
      parsed_arguments[words[0]]=words[1]
    elsif not COMMANDS.key?(arg)
      puts "Unknown command '%s'." % arg
      return false
    else
      if parsed_arguments.key? arg
        puts "Parse error, two commands found %s and %s" % parsed_arguments["command"], arg
        return false
      end
      parsed_arguments["command"] = arg
    end
  }

  return false unless parsed_arguments["command"] != nil
  return false unless parsed_arguments["command"] != ""

  return true
end

def main
  parsed_arguments = Hash.new
  begin
    print_usage
    return
  end unless read_arguments(ARGV, parsed_arguments)
  fileutil = FileUtil.new(parsed_arguments)
end

main