require 'yaml'
require 'algorithms'

def main
  config_path = ARGV[0]
  config_yml = YAML::load_file("#{config_path}")
  conf_array = config_yml["paths"]

  pq = Containers::PriorityQueue.new
  conf_array.each { |elem|
    priority = Time.now + 1000 * elem["scan_period"]
    pq.push([priority, elem], priority)
  }

  while true do
    puts pq.peak
    [time, conf] = pq.pop
    #MonitorPath::monitor_path()
    sleep(Time.now)
    print conf["path"]
    print conf["scan_period"]

    pq.push(conf, Time.now + 1000 * conf["scan_period"])
  end

end

main