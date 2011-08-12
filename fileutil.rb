#!/usr/bin/ruby

# This file is the basic file manipulation tool for the distributed system.
# All the basic commands should reside here.

require './content_data.rb'
require './argument_parser.rb'

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
    elsif (arguments["command"] == "merge" or
      arguments["command"] == "intersect" or
      arguments["command"] == "minus")

      begin
        puts "--cd_a is not set"
        return
      end unless not arguments["cd_a"].nil?
      cd_a = ContentData.new()
      cd_a.from_file(arguments["cd_a"])
      begin
        puts "Error loading content data cd_a=%s" % arguments["cd_a"]
        return
      end unless not cd_a.nil?

      begin
        puts "--cd_b is not set"
        return
      end unless not arguments["cd_b"].nil?
      cd_b = ContentData.new()
      cd_b.from_file(arguments["cd_b"])
      begin
        puts "Error loading content data cd_a=%s" % arguments["cd_b"]
        return
      end unless not cd_b.nil?

      begin
        puts "--dest is not set"
        return
      end unless not arguments["dest"].nil?

      output = FileUtil.contet_data_command(arguments["command"], cd_a, cd_b, arguments["dest"])
    end
  end

  def self.contet_data_command(command, cd_a, cd_b, dest_path)

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
COMMANDS["merge"] = "  merge --cd_a=<path> --cd_b=<path> --dest=<path>"
COMMANDS["intersect"] = "  intersect --cd_a=<path> --cd_b=<path> --dest=<path>"
COMMANDS["minus"] = "  minus --cd_a=<path> --cd_b=<path> --dest=<path>"

def print_usage
    puts "Usage: fileutil <command> parameters..."
    puts "Commands:"
    COMMANDS.each { |name, description|
      puts description
    }
end

def main
  parsed_arguments = Hash.new
  begin
    print_usage
    return
  end unless ReadArgs.read_arguments(ARGV, parsed_arguments, COMMANDS)
  fileutil = FileUtil.new(parsed_arguments)
end

main