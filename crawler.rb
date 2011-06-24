require 'configuration.rb'
require 'content_data.rb'
# Crawles the server topology and physical devices
# and indexes the relevant files

class Crawler
  
  def initialize(server_conf)
    threads = Array.new
    
    # Handle different devices
    devices = Hash.new
    server_conf.directories.each { |pattern|
      key = pattern.split(':')[0]
      if not devices.has_key?(key)
        devices[key] = Array.new
      end
      devices[key].push(key)
    }
    
    devices.each_key { |key|
      threads.push(Thread.new { handle_device(server_conf.name, key, devices[key]) })
    }
    
    # Handle different sub-servers
    server_conf.servers.each { |sub_server| 
      threads.push(Thread.new { handle_sub_server(server_conf.name, sub_server) })
    }
    
    threads.each { |a| a.join }
    
    join_sub_servers_results(server_conf.name, devices.keys, server_conf.servers)
  end
  
  def handle_device(server_name, device, pattern_arr)
    # Run indexer here!
    #Indexer.new(server_name, "%s_%s.data" % [server_name, device], pattern_arr)
    printf('Indexer.new(server_name, "%s_%s.data", pattern_arr)' % [server_name, device])
  end
  
  def handle_sub_server(server_name, sub_server)
    # remote ssh copy files . . .
    copy_crawler(sub_server)
    
    # remote ssh run Crawler . . .
    run_crawler(sub_server)
    
    # remote ssh copy files back ... 
    copy_back(sub_server)
  end

  def copy_crawler(sub_server)
    printf "copy_crawler: %s\n", sub_server.name
    
    sub_server_conf = '%s.conf' % sub_server.name
    sub_server.to_file(sub_server_conf)
    
    dir_perm = 0755
    Net::SSH.start(sub_server.name, sub_server.username) do |ssh|
      ssh.sftp.connect do |sftp|
        sftp.mkdir!('crawler', :permissions => dir_perm)
        sftp.mkdir!('crawler/config', :permissions => dir_perm)
        sftp.put_file(sub_server_conf, 'crawler/config/server.conf')
      end
    end
  end

  def run_crawler(sub_server)
    printf "Running remote: %s\n", sub_server.name
    Net::SSH.start(sub_server.name, sub_server.username) do |ssh|
      ssh.exec!('cd crawler')
      ssh.exec!('ruby crawler("config/server.conf")')
      #Crawler.new(sub_server)
    end
  end

  def copy_back(sub_server)
    printf "copy_back: %s\n", sub_server.name
    sub_server_conf = '%s.data' % sub_server.name
    Net::SSH.start(sub_server.name, sub_server.username) do |ssh|
      ssh.sftp.connect do |sftp|
        sftp.get_file(sub_server_conf, sub_server_conf)
      end
    end
  end
  
  def join_sub_servers_results(server_name, devices, sub_servers)
    content_data = ContentData.new
    devices.each { |device|
      device_content_data = ContentData.new
      device_content_data.from_file("%s_%s.data" % [server_name, device])
      content_data.merge(device_content_data)
    }

    sub_servers.each { |sub_server|
      sub_server_content_data = ContentData.new
      sub_server_content_data.from_file("%s.data" % [sub_server.name])
      content_data.merge()
    }
    content_data.to_file("%s.data" % server_name)
  end
  
end

def join_servers_results(server_conf_vec)
    if (server_conf_vec.length > 1)
      content_data = ContentData.new
      server_conf_vec.each { |server|
        sub_server_content_data = ContentData.new
        sub_server_content_data.from_file("%s.data" % [server.name])
        content_data.merge()
      }
      content_data.to_file("final.data")
    end
end

def main
  conf = Configuration.new(ARGV[0])
  
  threads = Array.new

  conf.server_conf_vec.each { |server|
    threads.push(Thread.new { Crawler.new(server) })
  }

  threads.each { |a| a.join }

  join_servers_results(server_conf_vec)
end

main