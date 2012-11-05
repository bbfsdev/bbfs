require 'process_monitoring/send_email'

emailOpt = {
    :body => 'dddd',
    :subject => 'BBFS Error Log notification',
}

BBFS::SendEmail.send_email('slavapas13@gmail.com', emailOpt)

