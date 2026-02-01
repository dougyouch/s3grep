require 'aws-sdk-s3'
require 'cgi'
require 'zlib'

module S3Grep
  class Search
    # Maximum bytes to process to prevent resource exhaustion
    MAX_BYTES_PROCESSED = 100 * 1024 * 1024  # 100MB

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
    def each_line_raw(&block)
      buffer = "".b
      bytes_processed = 0

      aws_s3_client.get_object(bucket: bucket, key: key) do |chunk|
        bytes_processed += chunk.bytesize
        check_size_limit!(bytes_processed)

        buffer << chunk
        extract_lines!(buffer, &block)
      end

      # Yield any remaining content (last line without newline)
      yield buffer unless buffer.empty?
    end

    # Stream gzip content line by line using Zlib::Inflate
    def each_line_gzip(&block)
      buffer = "".b
      bytes_processed = 0
      # Zlib::MAX_WBITS + 16 enables gzip format detection
      inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)

      begin
        aws_s3_client.get_object(bucket: bucket, key: key) do |chunk|
          decompressed = inflater.inflate(chunk)
          bytes_processed += decompressed.bytesize
          check_size_limit!(bytes_processed)

          buffer << decompressed
          extract_lines!(buffer, &block)
        end

        # Finish decompression and process remaining data
        remaining = inflater.finish
        bytes_processed += remaining.bytesize
        check_size_limit!(bytes_processed)
        buffer << remaining
        extract_lines!(buffer, &block)

        yield buffer unless buffer.empty?
      ensure
        inflater.close
      end
    end

    # ZIP files cannot be truly streamed (need central directory at EOF)
    # Fall back to buffered mode with size limit check
    def each_line_zip(&block)
      require 'zip'

      # For ZIP, we must buffer the entire file to access the archive
      body = StringIO.new("".b)
      bytes_downloaded = 0

      aws_s3_client.get_object(bucket: bucket, key: key) do |chunk|
        bytes_downloaded += chunk.bytesize
        check_size_limit!(bytes_downloaded)
        body << chunk
      end

      body.rewind
      zip = Zip::File.open_buffer(body)
      entry = zip.entries.first
      raise IOError, "ZIP archive is empty" if entry.nil?

      bytes_processed = 0
      buffer = "".b

      entry.get_input_stream.each do |chunk|
        bytes_processed += chunk.bytesize
        check_size_limit!(bytes_processed)

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

    def check_size_limit!(bytes)
      if bytes > MAX_BYTES_PROCESSED
        raise IOError, "Data exceeds maximum size limit (#{MAX_BYTES_PROCESSED} bytes). " \
                       "Set S3Grep::Search::MAX_BYTES_PROCESSED to increase."
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
