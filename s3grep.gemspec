# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 's3grep'
  s.version     = '0.2.0'
  s.licenses    = ['MIT']
  s.summary     = 'Search through S3 files without downloading them'
  s.description = 'CLI tools for streaming search (s3grep), viewing (s3cat), and reporting (s3info, s3report) on S3 objects. Supports gzip compression and searches large files with minimal memory usage.'
  s.authors     = ['Doug Youch']
  s.email       = 'dougyouch@gmail.com'
  s.homepage    = 'https://github.com/dougyouch/s3grep'
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir      = 'bin'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }

  s.required_ruby_version = '>= 2.6.0'

  s.add_runtime_dependency 'aws-sdk-s3'
  s.add_runtime_dependency 'rubyzip'
end
