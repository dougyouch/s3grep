# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

s3grep is a Ruby gem for searching through S3 files without downloading them. It provides CLI tools for grep-like searching, file viewing, and bucket reporting directly on S3 objects.

## Development Commands

```bash
# Install dependencies
bundle install

# Build the gem
gem build s3grep.gemspec

# Install locally for testing
gem install s3grep-*.gem
```

## CLI Tools

- `s3grep` - Search for patterns in S3 files (supports `-i` for case-insensitive, `-r` for recursive, `--include` for file patterns)
- `s3cat` - Stream S3 file contents to stdout
- `s3info` - Get directory statistics (file count, size, storage classes, date ranges) as JSON
- `s3report` - Generate CSV report of all buckets in an AWS account

## Architecture

**Core Classes (lib/s3grep/):**

- `Search` - Streams S3 objects and searches line-by-line with regex. Auto-detects compression (.gz, .zip)
- `Directory` - Lists S3 objects with prefix filtering. Handles pagination via marker-based iteration
- `DirectoryInfo` - Aggregates statistics from Directory iteration (counts, sizes, timestamps by storage class)

**S3 URL Convention:** All tools use `s3://bucket-name/path/to/object` format. The bucket name is parsed from the URL host, and the path becomes the S3 key prefix.

**AWS Authentication:** Uses default AWS SDK credential chain (env vars, ~/.aws/credentials, IAM roles). Region-specific clients are created automatically for cross-region bucket access in s3report.

## Code Commits

Format using angular formatting:
```
<type>(<scope>): <short summary>
```
- **type**: build|ci|docs|feat|fix|perf|refactor|test
- **scope**: The feature or component of the service we're working on
- **summary**: Summary in present tense. Not capitalized. No period at the end.

## Documentation Maintenance

When modifying the codebase, keep documentation in sync:
- **ARCHITECTURE.md** - Update when adding/removing classes, changing component relationships, or altering data flow patterns
- **README.md** - Update when adding new features, changing public APIs, or modifying usage examples
