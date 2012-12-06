require 'log'
require 'params'
require 'thread'

require 'process_monitoring/send_email'

module BBFS
  module Monitoring
    Params.float('monitoring_sleep_time_in_seconds', 10,
                 'Represents the monitoring sleeping time in seconds to check data')
    Params.float('send_email_duration_4_monitoring_state', 60*60,  # Once per hour.
                 'Represents the duration in seconds to send email monitoring state')

    Params.string('monitoring_email', 'bbfsdev@gmail.com','Represents the email for monitoring.')
    Params.string('monitoring_password', 'rndnorth1','Password for monitoring.')

    class Monitoring < BBFS::Log::Consumer
      attr_reader :thread

      def initialize(process_variables)
        super(false)
        @passed_time_dur = 0
        @process_variables = process_variables
        @thread = Thread.new do
          loop do
            Log.info 'Sleeping in process monitoring.'
            sleep(Params['monitoring_sleep_time_in_seconds'])
            Log.info 'Awake in process monitoring.'
            @passed_time_dur += Params['monitoring_sleep_time_in_seconds']
            Log.info 'handle_logs in process monitoring.'
            handle_logs()
            Log.info 'handle_monitoring_state in process monitoring.'
            handle_monitoring_state()
            @process_variables.inc('monitoring_loop_count')
          end
        end
        # For debug purposes.
        @thread.abort_on_exception = true
      end

      private
      # To keep thread safe state all methods should be private and executed only from @thread
      def send_log_email(log)
        BBFS::SendEmail.send_email({
          :to => Params['monitoring_email'],
          :from => Params['monitoring_email'],
          :password => Params['monitoring_password'],
          :body => log,
          :subject => 'BBFS Error Log notification',
        })
      end

      def send_monitoring_state_email
        BBFS::SendEmail.send_email({
          :to => Params['monitoring_email'],
          :from => Params['monitoring_email'],
          :password => Params['monitoring_password'],
          :body => get_monitoring_state_body(),
          :subject => 'BBFS Current Monitoring State notification',
        })
      end

      # Override logs consumer handler.
      def handle_logs
        while log_msg = @consumer_queue.pop(non_block=true) do
          send_log_email(log_msg) if Log.is_error(log_msg)
        end rescue ThreadError  # Rescue when queue is empty.
      end

      def handle_monitoring_state
        if @passed_time_dur > Params['send_email_duration_4_monitoring_state']
          send_monitoring_state_email()
          @passed_time_dur = 0
        end
      end

      def get_monitoring_state_body
        # TODO(slava): Implement the following function.
        # BBFS::MonitoringInfo::MonitoringInfo.get_html(@process_variables)
        "server_name: #{@process_variables.get('server_name')}\n" +
        "num_files_received: #{@process_variables.get('num_files_received')}\n" +
        "monitoring_loop_count: #{@process_variables.get('monitoring_loop_count')}"
      end
    end
  end
end
