require 'aws-sdk-s3'
require 'cgi'

module S3Grep
  class Search
    attr_reader :s3_url,
                :aws_s3_client,
                :compression

    def initialize(s3_url, aws_s3_client, compression = nil)
      @s3_url = s3_url
      @aws_s3_client = aws_s3_client
      @compression = compression
    end

    def self.search(s3_url, aws_s3_client, regex, &block)
      new(s3_url, aws_s3_client, detect_compression(s3_url)).search(regex, &block)
    end

    def self.detect_compression(s3_url)
      return :gzip if s3_url =~ /\.gz$/i
      return :zip if s3_url =~ /\.zip$/i

      nil
    end

    def search(regex)
      line_number = 0
      to_io.each do |line|
        line_number += 1
        next unless line.match?(regex)

        yield line_number, line
      end
    end

    def s3_object
      uri = URI(s3_url)

      aws_s3_client.get_object(
        {
          bucket: uri.host,
          key: CGI.unescape(uri.path[1..-1])
        }
      )
    end

    def to_io
      body = s3_object.body

      if compression == :gzip
        Zlib::GzipReader.new(body)
      elsif compression == :zip
        require 'rubyzip'
        zip = Zip::File.open_buffer(body)
        zip.entries.first.get_input_stream
      else
        body
      end
    end
  end
end
