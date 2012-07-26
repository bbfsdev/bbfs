require 'rspec'
require 'tempfile'

require_relative '../../lib/file_indexing/index_agent.rb'

module BBFS
  module FileCopy
    module Spec

      describe 'checksum' do
        it 'should generate correct checksum' do
          # The test does not checks the problem the problem is when reading from File
          # class which handles read(num) different from read()
          content = ''
          100000.times { content << 'abagadavazahatikalamansapazkareshet' }
          content_checksum = FileIndexing::IndexAgent.get_content_checksum(content)

          stream = StringIO.new(content)
          File.stub(:new).and_return(stream)
          file_checksum = FileIndexing::IndexAgent.get_checksum('kuku')

          content_checksum.should == file_checksum
          content_checksum.should == '381e99eb0e2dfcaf45c9a367a04a4197ef3039a6'
        end

        it 'should generate correct checksum for temp file' do
          file = Tempfile.new('foo')
          path = file.path
          1.times { file.write('abagadavazahatikalamansapazkareshet') }
          file.close()

          file_checksum = FileIndexing::IndexAgent.get_checksum(path)

          file = Tempfile.open('foo')
          content = file.read()
          content_checksum = FileIndexing::IndexAgent.get_content_checksum(content)

          puts "LALALALALAL .#{content}."

          file_checksum.should == content_checksum.should
          file_checksum.should == '381e99eb0e2dfcaf45c9a367a04a4197ef3039a6'
          content_checksum.should == '381e99eb0e2dfcaf45c9a367a04a4197ef3039a6'
        end

      end
    end
  end
end
