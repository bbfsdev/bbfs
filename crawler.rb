require 'rubygems'
require './configuration.rb'
require './content_data.rb'
require './index_agent.rb'
require './argument_parser.rb'
require './net_utils.rb'
require 'net/ssh'
require 'net/sftp'

# Crawles the server topology and physical devices
# and indexes the relevant files

class Crawler

  def initialize(server_conf, out_name, cd_in_name)
    if (server_conf.name == 'localhost')
      threads = Array.new

      # Handle different devices
      devices = Hash.new
      server_conf.directories.each { |pattern|
        key = pattern.split(':')[0]
        if not devices.has_key?(key)
          devices[key] = Array.new
        end
        devices[key].push(pattern)
      }

      devices.each_key { |key|
        threads.push(Thread.new { handle_device(out_name, key, devices[key], cd_in_name) })
      }

      # Handle different sub-servers
      server_conf.servers.each { |sub_server|
        threads.push(Thread.new { handle_sub_server(sub_server, cd_in_name) })
      }

      threads.each { |a| a.join }

      join_sub_servers_results(out_name, devices.keys, server_conf.servers)
    else
      handle_sub_server(server_conf, cd_in_name)
    end
  end

  def handle_device(server_name, device, pattern_arr, cd_in_name)
    # Run indexer here!
    p "Handling device %s on %s" % [device, server_name]
    p "Patterns are: %s" % pattern_arr
    cd_in = nil
    if cd_in_name
      cd_in = ContentData.new
      cd_in.from_file(cd_in_name)
    end

    agent = IndexAgent.new(server_name, device)
    agent.index(pattern_arr, cd_in)
    agent.db.to_file("%s_%s.data" % [server_name, device])
  end

  def handle_sub_server(sub_server, cd_in_name)
    # remote ssh copy files . . .
    copy_crawler(sub_server, cd_in_name)

    # remote ssh run Crawler . . .
    run_crawler(sub_server, cd_in_name)

    # remote ssh copy files back ...
    copy_back(sub_server)
  end

  def copy_crawler(sub_server, cd_in_name)
    printf "copy_crawler: %s@%s\n", sub_server.username, sub_server.name

    tmp_name = sub_server.name
    sub_server.name = 'localhost' # So that the remote server will handle the request locally
    sub_server_conf = 'server.conf'
    sub_server.to_file(sub_server_conf)
    sub_server.name = tmp_name

    dir_perm = 0755
    ssh = connect(sub_server)
    ssh.sftp.connect do |sftp|
      begin
        sftp.mkdir!('crawler', :permissions => dir_perm)
        sftp.mkdir!('crawler/config', :permissions => dir_perm)
      rescue Net::SFTP::StatusException => e
        print "Directories already exist.\n"
      end
      Dir.foreach('.') do |file|
        if file.end_with?('.rb')
          sftp.upload!(file, 'crawler/%s' % [file])
        end
      end
      sftp.upload!(sub_server_conf, 'crawler/config/server.conf')
      if cd_in_name
        sftp.upload!(cd_in_name, 'crawler/config/cd_in.data')
      end
    end
  end

  def run_crawler(sub_server, cd_in_name)
    printf "Running remote: %s\n", sub_server.name
    ssh = connect(sub_server)

    cd_in_arguments = ""
    if (cd_in_name)
      cd_in_arguments = " --cd_in=config/cd_in.data"
    end

    puts "running: cd crawler && ruby crawler.rb --conf_file=config/server.conf --cd_out=%s%s" % [sub_server.name, cd_in_arguments]
    output = ssh.exec!('cd crawler && ruby crawler.rb --conf_file=config/server.conf --cd_out=%s%s' % [sub_server.name, cd_in_arguments])
    printf "%s\n", output
  end

  def copy_back(sub_server)
    printf "copy_back: %s.data\n", sub_server.name
    ssh = connect(sub_server)
    ssh.sftp.connect do |sftp|
      begin
        local_path = "%s.data" % [sub_server.name]
        sub_server_conf = "crawler/%s.data" % [sub_server.name]
        printf "copying %s . . .\n", sub_server_conf
        sftp.download!(sub_server_conf, local_path)
      rescue RuntimeError => e
        print "Could not copy file back.\n"
        print e
        print "\n"
      end
    end
  end

  def join_sub_servers_results(server_name, devices, sub_servers)
    content_data = ContentData.new
    devices.each { |device|
      device_content_data = ContentData.new
      print "merging %s_%s.data\n" % [server_name, device]
      device_content_data.from_file("%s_%s.data" % [server_name, device])
      content_data.merge(device_content_data)
    }

    sub_servers.each { |sub_server|
      sub_server_content_data = ContentData.new
      print "merging %s.data\n" % [sub_server.name]
      sub_server_content_data.from_file("%s.data" % [sub_server.name])
      content_data.merge(sub_server_content_data)
    }
    print "writing to file %s.data\n" % server_name
    content_data.to_file("%s.data" % server_name)
  end

end

def join_servers_results(server_conf_vec, out_name)
  if (!server_conf_vec.nil? && server_conf_vec.length > 1)
    content_data = ContentData.new
    server_conf_vec.each { |server|
      sub_server_content_data = ContentData.new
      sub_server_content_data.from_file("%s.data" % [server.name])
      content_data.merge(sub_server_content_data)
    }
    print "writing output to file %s.data\n" % out_name
    content_data.to_file(out_name+'.data')
  elsif (!server_conf_vec.nil? && server_conf_vec.length == 1)
    if (server_conf_vec[0].name != "localhost")
      # TODO(kolman): Should simply rename file.
      content_data = ContentData.new
      sub_server_content_data = ContentData.new
      sub_server_content_data.from_file("%s.data" % [server_conf_vec[0].name])
      content_data.merge(sub_server_content_data)
      content_data.to_file(out_name+'.data')
    end
  elsif (server_conf_vec.nil? || server_conf_vec.length == 0)
    content_data = ContentData.new
    content_data.to_file(out_name+'.data')
  end
end

def main
  parsed_arguments = Hash.new
  begin
    print_usage
    return
  end unless ReadArgs.read_arguments(ARGV, parsed_arguments)

  conf = Configuration.new(parsed_arguments["conf_file"])
  threads = Array.new

  out_name = "out"
  if parsed_arguments.has_key? "cd_out"
    out_name = parsed_arguments["cd_out"]
  end

  cd_in_name = nil
  if parsed_arguments.has_key? "cd_in"
    cd_in_name = parsed_arguments["cd_in"]
  end

  conf.server_conf_vec.each { |server|
    threads.push(Thread.new { Crawler.new(server, out_name, cd_in_name) })
  }

  threads.each { |a| a.join }

  join_servers_results(conf.server_conf_vec, out_name)
end

def print_usage
    puts "Usage: ruby crawler.rb --conf_file=<conf file> --cd_out=<outpt content data name> --cd_in=<existing content data - optional>"
end

main