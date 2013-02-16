require 'net/smtp'

module Email

  def Email.send_email(from, password, to, mail_text)
    smtp = Net::SMTP.new('smtp.gmail.com', 587)
    smtp.enable_starttls
    smtp.start(from.split('@')[-1], from, password, :login) do
      smtp.send_message(mail_text, from, to)
    end
  end

  def Email.send_attachments_email(from, password, to, subject, body, attachments)
    # Read a file and encode it into base64 format
    begin
      encoded_attachments = []
      attachments.each do |attachment|
        file_content = File.read(attachment)
        encoded_content = [file_content].pack("m")   # base64
        encoded_attachments << [attachment, encoded_content]
      end
    rescue
      raise "Could not read file #{attachment}"
    end

    marker = (0...50).map{ ('a'..'z').to_a[rand(26)] }.join
    parts = []
    parts << <<EOF
From: #{from}
To: #{to}
Subject: #{subject}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{marker}
--#{marker}
EOF

    # Define the message action
    parts << <<EOF
Content-Type: text/plain
Content-Transfer-Encoding:8bit

#{body}
--#{marker}
EOF

    encoded_attachments.each do |attachment, encoded_content|
    # Define the attachment section
    parts << <<EOF
Content-Type: multipart/mixed; name=\"#{File.basename(attachment)}\"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="#{File.basename(attachment)}"

#{encoded_content}
--#{marker}--
EOF
    end

    mailtext = parts.join('')
    send_email(from, password, to, mailtext)
  end

end
