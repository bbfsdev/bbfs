require 'log'
require 'params'

# Testing server. Assumes that content and backup servers are running.
# The server runs 24-7, generates/deletes files and validates content at backup periodically.
module TestingServer

  #Parameters

  def run_testing_server
    all_threads = []

    @process_variables = ThreadSafeHash::ThreadSafeHash.new
    @process_variables.set('server_name', 'testing_server')

    # Enable monitoring + collect monitoring data from both servers.

    # Make this loop as stand alone thread.
    loop do
      # Generate files.
      # Wait some time.
      # Validate files.
      # Send email.
    end

    # Finalize server threads.
    all_threads.each { |t| t.abort_on_exception = true }
    all_threads.each { |t| t.join }
    # Should never reach this line.
  end
  module_function :run_testing_server

end # module TestingServer


