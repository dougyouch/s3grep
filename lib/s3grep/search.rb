require 'aws-sdk-s3'
require 'cgi'

module S3Grep
  class Search
    # Maximum decompressed size (100MB) to prevent decompression bombs
    MAX_DECOMPRESSED_SIZE = 100 * 1024 * 1024

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
        create_limited_gzip_reader(body)
      elsif compression == :zip
        require 'zip'
        create_limited_zip_reader(body)
      else
        body
      end
    end

    private

    # Wrapper IO that enforces a size limit during decompression
    class LimitedIO
      def initialize(io, limit)
        @io = io
        @limit = limit
        @bytes_read = 0
      end

      def each(&block)
        @io.each do |chunk|
          @bytes_read += chunk.bytesize
          if @bytes_read > @limit
            raise IOError, "Decompressed data exceeds maximum size limit (#{@limit} bytes). Possible decompression bomb."
          end
          yield chunk
        end
      end
    end

    def create_limited_gzip_reader(body)
      LimitedIO.new(Zlib::GzipReader.new(body), MAX_DECOMPRESSED_SIZE)
    end

    def create_limited_zip_reader(body)
      zip = Zip::File.open_buffer(body)
      entry = zip.entries.first
      raise IOError, "ZIP archive is empty" if entry.nil?

      if entry.size > MAX_DECOMPRESSED_SIZE
        raise IOError, "ZIP entry size (#{entry.size} bytes) exceeds maximum limit (#{MAX_DECOMPRESSED_SIZE} bytes). Possible decompression bomb."
      end

      LimitedIO.new(entry.get_input_stream, MAX_DECOMPRESSED_SIZE)
    end
  end
end
