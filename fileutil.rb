#!/usr/bin/ruby

# This file is the basic file manipulation tool for the distributed system.
# All the basic commands should reside here.

require './content_data.rb'
require './argument_parser.rb'
require './copy.rb'

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
        puts "Error loading content data cd_b=%s" % arguments["cd_b"]
        return
      end unless not cd_b.nil?

      begin
        puts "--dest is not set"
        return
      end unless not arguments["dest"].nil?

      output = FileUtil.contet_data_command(arguments["command"], cd_a, cd_b, arguments["dest"])
    elsif arguments["command"] == "copy"
      begin
        puts "--conf is not set"
        return
      end unless not arguments["conf"].nil?
      conf = Configuration.new(arguments["conf"])

      begin
        puts "Error loading content data conf=%s" % arguments["conf"]
        return
      end unless not conf.nil?

      begin
        puts "--cd is not set"
        return
      end unless not arguments["cd"].nil?
      cd = ContentData.new()
      cd.from_file(arguments["cd"])
      begin
        puts "Error loading content data cd=%s" % arguments["cd"]
        return
      end unless not cd.nil?

      begin
        puts "--dest_server is not set"
        return
      end unless not arguments["dest_server"].nil?
      dest_server = arguments["dest_server"]

      begin
        puts "--dest_path is not set"
        return
      end unless not arguments["dest_path"].nil?
      dest_path = arguments["dest_path"]

      Copy.new(conf, cd, dest_server, dest_path)
    end
  end

  def self.contet_data_command(command, cd_a, cd_b, dest_path)
    dest = nil
    if command == "merge"
      dest = ContentData.merge(cd_a, cd_b)
    elsif command == "intersect"
      dest = ContentData.intersect(cd_a, cd_b)
    elsif command == "minus"
      dest = ContentData.remove(cd_b, cd_a)
    end
    if dest
      dest.to_file(dest_path)
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

    warnings = Array.new

    ref_cd.instances.values.each { |instance|
      if inverted_index.key? instance.checksum
        
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
COMMANDS["copy"] = "  copy --conf=<path> --cd=<path> --dest_server=<server name> --dest_path=<dir>"

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