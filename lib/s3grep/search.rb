module S3Grep
  class Search
    attr_reader :s3_url,
                :aws_s3_client

    def initialize(s3_url, aws_s3_client)
      self.s3_url = s3_url
      self.aws_s3_client = aws_s3_client
    end

    def self.search(s3_url, aws_s3_client, regex, &block)
      new(s3_url, aws_s3_client).search(regex, &block)
    end

    def search(regex)
      body = s3_object.body

      line_number = 0
      body.each do |line|
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
          key: uri.path[1..-1]
        }
      )
    end
  end
end
