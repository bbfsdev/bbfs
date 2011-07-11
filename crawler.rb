require 'rubygems'
require 'configuration.rb'
require 'content_data.rb'
require 'index_agent.rb'
require 'net/ssh'
require 'net/sftp'

# Crawles the server topology and physical devices
# and indexes the relevant files

class Crawler  
  
  
  def initialize(server_conf, is_localhost=true)    
    #    if (server_conf.name == 'localhost')
    if (is_localhost == true)
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
        threads.push(Thread.new { handle_device(server_conf.name, key, devices[key]) })
      }
    
      # Handle different sub-servers
      server_conf.servers.each { |sub_server| 
        threads.push(Thread.new { handle_sub_server(sub_server) })
      }
    
      threads.each { |a| a.join }
    
      join_sub_servers_results(server_conf.name, devices.keys, server_conf.servers)
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
#    sub_server.name = 'localhost' # So that the remote server will handle the request locally
    sub_server_conf = 'server.conf'
    sub_server.to_file(sub_server_conf)
    sub_server.name = tmp_name

    dir_perm = 0755
    Net::SSH.start(sub_server.name, sub_server.username, 
                  :password => sub_server.password,
                  :encryption => 'none',
                  :auth_methods => 'password',
                  :port => sub_server.port) do |ssh|
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
  end

  def run_crawler(sub_server)
    printf "Running remote: %s\n", sub_server.name
    Net::SSH.start(sub_server.name, sub_server.username, 
                   :password => sub_server.password,
                   :encryption => 'none',
                   :auth_methods => 'password',
                   :port => sub_server.port) do |ssh|
      #ssh.shell.sync.cd('crawler') 
      #output = ssh.exec!('cd crawler')
      #printf "first:%s\n", output
      #output = ssh.exec!('touch crawler/csm.technion.ac.il.data')
      #printf "second:%s\n", output    
      output = ssh.exec!('cd crawler && ruby crawler.rb config/server.conf')
      printf "%s\n", output
      #Crawler.new(sub_server)
    end
  end

  def copy_back(sub_server)
    printf "copy_back: %s\n", sub_server.name
    #sub_server_conf = '%s.data' % sub_server.name
    
    Net::SSH.start(sub_server.name, sub_server.username, 
                   :password => sub_server.password,
                   :encryption => 'none',
                   :auth_methods => 'password',
                   :port => sub_server.port) do |ssh|
      ssh.sftp.connect do |sftp|
        #sftp.download!(sub_server_conf, sub_server_conf)
        begin
          devices = Array.new
          sub_server.directories.each do |pattern|
            devices.push(pattern.split(':')[0])
          end
          devices.uniq!.each do |device|
            sub_server_conf = '%s_%s.data' % [sub_server.name, device]
            sftp.download!("crawler/#{sub_server_conf}", sub_server_conf)              
          end
        rescue RuntimeError => e
          print "Could not copy file back.\n"
        end
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
  return unless(conf.server_conf_vec != nil)
  threads = Array.new

  conf.server_conf_vec.each { |server|
    threads.push(Thread.new { Crawler.new(server, ARGV[1] == nil ? true : false) })
  }

  threads.each { |a| a.join }

  join_servers_results(conf.server_conf_vec)
end

main