require 'aws-sdk-s3'
require 'cgi'
require 'zlib'

module S3Grep
  class Search
    attr_reader :s3_url,
                :aws_s3_client,
                :compression

    def initialize(s3_url, aws_s3_client, compression = nil)
      @s3_url = s3_url
      @aws_s3_client = aws_s3_client
      @compression = compression || self.class.detect_compression(s3_url)
    end

    def self.search(s3_url, aws_s3_client, regex, &block)
      new(s3_url, aws_s3_client).search(regex, &block)
    end

    def self.detect_compression(s3_url)
      return :gzip if s3_url =~ /\.gz$/i
      return :zip if s3_url =~ /\.zip$/i

      nil
    end

    # Create a non-retrying client for streaming operations
    # Retries are incompatible with streaming because chunks can't be replayed
    def streaming_client
      @streaming_client ||= Aws::S3::Client.new(
        retry_limit: 0,
        region: aws_s3_client.config.region
      )
    end

    def search(regex)
      line_number = 0
      each_line do |line|
        line_number += 1
        next unless line.match?(regex)

        yield line_number, line
      end
    end

    # Stream lines from S3 without loading entire file into memory
    def each_line(&block)
      if compression == :gzip
        each_line_gzip(&block)
      elsif compression == :zip
        each_line_zip(&block)
      else
        each_line_raw(&block)
      end
    end

    # For backward compatibility - streams content for s3cat
    def to_io
      StreamingIO.new(self)
    end

    def bucket
      @bucket ||= URI(s3_url).host
    end

    def key
      @key ||= CGI.unescape(URI(s3_url).path[1..-1])
    end

    private

    # Stream raw (uncompressed) content line by line
    # True streaming - only keeps current chunk + line buffer in memory
    def each_line_raw(&block)
      buffer = "".b

      streaming_client.get_object(bucket: bucket, key: key) do |chunk|
        buffer << chunk
        extract_lines!(buffer, &block)
      end

      # Yield any remaining content (last line without newline)
      yield buffer unless buffer.empty?
    end

    # Stream gzip content line by line
    # True streaming - decompresses chunks as they arrive from S3
    def each_line_gzip(&block)
      buffer = "".b
      # Zlib::MAX_WBITS + 32 enables automatic gzip/zlib header detection
      inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 32)

      begin
        streaming_client.get_object(bucket: bucket, key: key) do |chunk|
          # Decompress this chunk
          decompressed = inflater.inflate(chunk)
          buffer << decompressed
          extract_lines!(buffer, &block)
        end

        # Finish decompression and process remaining data
        remaining = inflater.finish
        buffer << remaining
        extract_lines!(buffer, &block)

        yield buffer unless buffer.empty?
      ensure
        inflater.close
      end
    end

    # ZIP files cannot be truly streamed (central directory is at EOF)
    # We stream the download but must buffer before decompressing
    def each_line_zip(&block)
      require 'zip'

      # Stream download into buffer (ZIP format requires full file)
      body = StringIO.new("".b)
      streaming_client.get_object(bucket: bucket, key: key) do |chunk|
        body << chunk
      end
      body.rewind

      zip = Zip::File.open_buffer(body)
      entry = zip.entries.first
      raise IOError, "ZIP archive is empty" if entry.nil?

      buffer = "".b
      entry.get_input_stream.each do |chunk|
        buffer << chunk
        extract_lines!(buffer, &block)
      end

      yield buffer unless buffer.empty?
    end

    # Extract complete lines from buffer, yielding each one
    def extract_lines!(buffer)
      while (newline_index = buffer.index("\n"))
        line = buffer.slice!(0, newline_index + 1)
        yield line
      end
    end

    # Adapter class that provides IO-like interface for streaming
    # Used by s3cat for backward compatibility
    class StreamingIO
      def initialize(search)
        @search = search
      end

      def each(&block)
        @search.each_line(&block)
      end
    end
  end
end
