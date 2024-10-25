module S3Grep
  class DirectoryInfo
    attr_reader :bucket,
                :base_prefix,
                :total_size,
                :num_files,
                :newest_content,
                :oldest_content,
                :num_files_by_storage_class,
                :total_size_by_storage_class

    def self.get(directory)
      info = new(directory)
      info.process(directory)
    end

    def initialize(directory)
      @total_size = 0
      @num_files = 0
      @num_files_by_storage_class = Hash.new(0)
      @total_size_by_storage_class = Hash.new(0)
      set_path(directory)
    end

    def process(directory)
      directory.each_content do |content|
        @num_files += 1
        @total_size += content[:size]

        @num_files_by_storage_class[content[:storage_class]] += 1
        @total_size_by_storage_class[content[:storage_class]] += content[:size]

        set_newest(content)
        set_oldest(content)
      end

      self
    end

    def last_modified
      @newest_content && @newest_content[:last_modified]
    end

    def newest_file
      @newest_content && @newest_content[:key]
    end

    def first_modified
      @oldest_content && @oldest_content[:last_modified]
    end

    def first_file
      @oldest_content && @oldest_content[:key]
    end

    def set_path(directory)
      uri = URI(directory.s3_url)
      @bucket = uri.host
      @base_prefix = CGI.unescape(uri.path[1..-1] || '')
    end

    def set_newest(content)
      if @newest_content.nil? || @newest_content[:last_modified] < content[:last_modified]
        @newest_content = content
      end
    end

    def set_oldest(content)
      if @oldest_content.nil? || @oldest_content[:last_modified] > content[:last_modified]
        @oldest_content = content
      end
    end
  end
end
