require 'net/smtp'

module BBFS
  module SendEmail
    #class SendEmail
    def SendEmail.send_email(to,opts={})
      opts[:server]      ||= 'localhost'
      opts[:from]        ||= 'BBFS@BBFS.com'
      opts[:from_alias]  ||= 'Example Emailer'
      opts[:subject]     ||= "BBFS Notification subject"
      opts[:body]        ||= "BBFS Body"

      msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
Subject: #{opts[:subject]}

      #{opts[:body]}
END_OF_MESSAGE

      Net::SMTP.start(opts[:server]) do |smtp|
        smtp.send_message msg, opts[:from], to
      end
    end
    #end
  end
end

