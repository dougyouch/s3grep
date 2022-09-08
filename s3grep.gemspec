# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 's3grep'
  s.version     = '0.1.3'
  s.licenses    = ['MIT']
  s.summary     = 'Search through S3 files'
  s.description = 'Tools for searching files on S3'
  s.authors     = ['Doug Youch']
  s.email       = 'dougyouch@gmail.com'
  s.homepage    = 'https://github.com/dougyouch/s3grep'
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir      = 'bin'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }

  s.add_runtime_dependency 'aws-sdk-s3'
end
