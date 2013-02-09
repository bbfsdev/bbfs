require 'rspec'

require_relative '../../lib/file_copy/copy.rb'

module FileCopy
  module Spec

    describe 'FileCopy::ssh_connect' do
      it 'should raise error when username not specified' do
        ENV.stub(:[]).with(any_args()).and_return(nil)
        expect { FileCopy::ssh_connect(nil, nil, 'a server') }.to raise_error "Undefined username"
      end

      it 'should raise error when server not specified' do
        expect { FileCopy::ssh_connect('kuku', nil, nil) }.to raise_error "Undefined server"
      end

      it 'should try to connect if username is set explicitly' do
        Net::SSH.should_receive(:start).with(any_args())
        FileCopy::ssh_connect('kuku', nil, 'a server')
      end
      it 'should try to connect if username is set via ENV variable' do
        Net::SSH.should_receive(:start).with(any_args())
        ENV.stub(:[]).with("USER").and_return('kuku')
        FileCopy::ssh_connect(nil, nil, 'a server')
      end
    end

    # TODO(kolman): Bad test, should rewrite and understand how to write test correctly.
    describe 'FileCopy::sftp_copy' do
      it 'call upload with correct files' do
        ssh_connection = double('Net::SSH::Connection')
        sftp_session = double('Net::SFTP::Session')
        uploader = double('Operations::Upload')
        sftp_attributes = double('Attributes')

        # Stubbing sftp.
        FileCopy.stub(:ssh_connect).and_return(ssh_connection)
        ssh_connection.stub(:sftp).and_return(sftp_session)
        sftp_session.stub(:connect).and_yield(sftp_session)
        sftp_session.stub(:stat!).and_return(sftp_attributes)
        sftp_attributes.stub(:directory?).and_return(true)
        uploader.stub(:wait).and_return(true, true)

        # Test file uploaded
        sftp_session.should_receive(:upload).with('a', 'b').and_return(uploader)
        sftp_session.should_receive(:upload).with('c', 'd').and_return(uploader)
        FileCopy::sftp_copy(nil, nil, nil, { 'a' => 'b', 'c' => 'd' })
      end
    end

  end
end

