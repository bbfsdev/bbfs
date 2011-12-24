require 'yaml'
require 'algorithms'
require './src/file_monitoring/monitor_path.rb'

def main
  config_path = ARGV[0]
  config_yml = YAML::load_file(config_path)
  conf_array = config_yml["paths"]

  pq = Containers::PriorityQueue.new
  conf_array.each { |elem|
    priority = (Time.now + elem["scan_period"]).to_i
    pq.push([priority, elem, DirStat.new(elem["path"], nil, nil, elem["stable_state"])], -priority)
  }

  puts config_yml["log_path"]

  log = File.open(config_yml["log_path"], 'w')
  FileStat.set_log(log)

  while true do
    time, conf, dir_stat = pq.pop
    #puts "time:" + time.to_s()
    #puts "now:" + Time.now.to_i.to_s()
    #puts conf

    time_span = time - Time.now.to_i
    if (time_span > 0)
      sleep(time_span)
    end

    dir_stat.monitor

    #puts conf["path"]
    #puts conf["scan_period"]
    priority = (Time.now + conf["scan_period"]).to_i
    pq.push([priority, conf, dir_stat], -priority)
  end

  log.close
end

main