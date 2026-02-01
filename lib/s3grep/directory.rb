require 'aws-sdk-s3'
require 'cgi'

# Purpose search through a directory on S3 for a specified file pattern
module S3Grep
  class Directory
    attr_reader :s3_url,
                :aws_s3_client

    def initialize(s3_url, aws_s3_client)
      @s3_url = s3_url
      @aws_s3_client = aws_s3_client
    end

    def uri
      @uri ||= URI(s3_url)
    end

    def self.glob(s3_url, aws_s3_client, regex, &block)
      new(s3_url, aws_s3_client).glob(regex, &block)
    end

    def glob(regex)
      each do |s3_file|
        next unless s3_file.match?(regex)

        yield s3_file
      end
    end

    def each
      each_content do |content|
        yield('s3://' + uri.host + '/' + escape_path(content.key))
      end
    end

    def each_content
      max_keys = 1_000

      prefix = CGI.unescape(uri.path[1..-1] || '')

      resp = aws_s3_client.list_objects(
        bucket: uri.host,
        prefix: prefix,
        max_keys: max_keys
      )

      resp.contents.each do |content|
        yield(content)
      end

      while resp.contents.size == max_keys
        marker = resp.contents.last.key

        resp = aws_s3_client.list_objects(
          bucket: uri.host,
          prefix: prefix,
          max_keys: max_keys,
          marker: marker
        )

        resp.contents.each do |content|
          yield(content)
        end
      end
    end

    def escape_path(s3_path)
      s3_path.split('/').map { |part| CGI.escape(part) }.join('/')
    end

    def info
      ::S3Grep::DirectoryInfo.get(self)
    end
  end
end
