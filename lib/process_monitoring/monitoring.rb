require 'log'
require 'params'
require 'thread'

module BBFS
  module Monitoring
    Params.float('monitoring_sleep_time_in_seconds', 10, 'Represents the monitoring sleeping time to check data')
    Params.float('send_email_duration_4_monitoring_state', 60, 'Represents the duration to send email monitoring state')
    Params.string('administrator_email', 'alexeyn66@gmail.com','Represents the email of administrator')

    class Monitoring < BBFS::Consumer
      attr_reader :thread

      def initialize(currentMonitoringState)
        super(false)
        @passed_time_dur = 0
        @logQueue = Array.new()
        @currentMonitoringState = currentMonitoringState
        @thread = Thread.new do
          loop do
            sleep(Params['sleep_time_in_seconds'])
            @passed_time_dur += Params['sleep_time_in_seconds']
            handle_logs()
            handle_monitoring_state()
          end
        end
      end


      def send_log_email(log)
        emailOpt = {
            :body => log,
            :subject => 'BBFS Error Log notification',
        }
        send_email(Params['administrator_email'], emailOpt)
      end

      def send_monitoring_state_email
        emailOpt = {
            :body => get_monitoring_state_body(),
            :subject => 'BBFS Current Monitoring State notification',
        }
        send_email(Params['administrator_email'], emailOpt)
      end

      def handle_logs
        # TODO(slava): to check
        while log_msg = @consumer_queue.pop do
          send_log_email(log_msg) if Log.is_error(log_msg)
        end
      end

      def handle_monitoring_state
        if @passed_time_dur > Params['send_email_duration_4_monitoring_state']
          send_monitoring_state_email()
          @passed_time_dur = 0
        end
      end

      def get_monitoring_state_body
        #TODO (slava)
        #BBFS::MonitoringInfo::MonitoringInfo.get_html(@currentMonitoringState)
        "Total files #{@currentMonitoringState.get('total_files')}"
      end
    end
  end
end