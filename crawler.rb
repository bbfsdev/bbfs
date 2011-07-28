require 'rubygems'
require './configuration.rb'
require './content_data.rb'
require './index_agent.rb'
require 'net/ssh'
require 'net/sftp'

# Crawles the server topology and physical devices
# and indexes the relevant files

class Crawler

  def initialize(server_conf, out_name)    
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
        threads.push(Thread.new { handle_device(out_name, key, devices[key]) })
      }
    
      # Handle different sub-servers
      server_conf.servers.each { |sub_server| 
        threads.push(Thread.new { handle_sub_server(sub_server) })
      }
    
      threads.each { |a| a.join }
    
      join_sub_servers_results(out_name, devices.keys, server_conf.servers)
    else       
      handle_sub_server(server_conf)
    end
  end
  
  def handle_device(server_name, device, pattern_arr)
    # Run indexer here!
    
    agent = IndexAgent.new(server_name, device)   
    agent.index(pattern_arr)     
    agent.db.to_file("%s_%s.data" % [server_name, device])
  end
  
  def handle_sub_server(sub_server)
    # remote ssh copy files . . .
    copy_crawler(sub_server)
    
    # remote ssh run Crawler . . .
    run_crawler(sub_server)
    
    # remote ssh copy files back ... 
    copy_back(sub_server)
  end

  def copy_crawler(sub_server)
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
      end      
  end

  def run_crawler(sub_server)
    printf "Running remote: %s\n", sub_server.name    
    ssh = connect(sub_server)     
    print "running: cd crawler && ruby crawler.rb config/server.conf %s\n" % sub_server.name
    output = ssh.exec!('cd crawler && ruby crawler.rb config/server.conf %s' % sub_server.name)
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

def connect(server)
  username = (server.username and server.username.length > 0) ? server.username : ENV['USER']
  password = (server.password and server.password.length > 0) ? server.password : nil
  port = (server.port) ? server.port : 22 # 22 is a standart SSH port   
  if (username and password)
    Net::SSH.start(server.name, username, 
                  :password => password,
                  :port => port)
  elsif (username)   
    Net::SSH.start(server.name, username, 
                  :port => port)   
  else
    raise "Undefined username"
  end
end

def main
  if (ARGV.length < 1)
    print "Usage: ruby crawler.rb <conf file>"
    return
  end
  out_name = "out"
  if (ARGV.length > 1)
    out_name = ARGV[1]
  end

  conf = Configuration.new(ARGV[0])
  threads = Array.new

  conf.server_conf_vec.each { |server|
    threads.push(Thread.new { Crawler.new(server, out_name) })
  }

  threads.each { |a| a.join }

  join_servers_results(conf.server_conf_vec, out_name)
end

main