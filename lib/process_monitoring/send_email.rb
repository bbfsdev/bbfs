require 'net/smtp'

require 'log'
require 'params'

module SendEmail
  Params.boolean('enable_monitoring_emails', false, 'Whether to send emails for process monitoring events.')

  #class SendEmail
  def SendEmail.send_email(opts={})
    opts[:to]          ||= ''  # Required.
    opts[:from]        ||= ''  # Required.
    opts[:from_alias]  ||= 'BBFS Monitoring'
    opts[:subject]     ||= 'BBFS Notification subject'
    opts[:body]        ||= 'BBFS Body'
    opts[:password]    ||= ''  # Required.

    msg = "From: #{opts[:from_alias]} <#{opts[:from]}>\n" \
          "To: <#{opts[:to]}>\n" \
          "Subject: #{opts[:subject]}\n" \
          "#{opts[:body]}"

    email_log_message = "Send actual email: #{Params['enable_monitoring_emails']}.\n" \
                        "to: #{opts[:to]}\n" \
                        "msg:#{msg}"
    if Params['enable_monitoring_emails']
      Log.debug1(email_log_message)
      smtp = Net::SMTP.new('smtp.gmail.com', 587)
      smtp.enable_starttls
      smtp.start('bbfs.com', opts[:from], opts[:password], :login) do
        smtp.send_message(msg, opts[:from], opts[:to])
      end
    else
      Log.info(email_log_message)
    end
  end
  #end
end


