require 'net/smtp'

module BBFS
  module SendEmail
    #class SendEmail
    def SendEmail.send_email(opts={})
      opts[:to]          ||= ''  # Required.
      opts[:from]        ||= ''  # Required.
      opts[:from_alias]  ||= 'BBFS Monitoring'
      opts[:subject]     ||= 'BBFS Notification subject'
      opts[:body]        ||= 'BBFS Body'
      opts[:password]    ||= ''  # Required.

      msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{opts[:to]}>
Subject: #{opts[:subject]}

      #{opts[:body]}
END_OF_MESSAGE

      smtp = Net::SMTP.new('smtp.gmail.com', 587)
      smtp.enable_starttls
      smtp.start('bbfs.com', opts[:from], opts[:password], :login) do
        smtp.send_message(msg, opts[:from], opts[:to])
      end
    end
    #end
  end
end

