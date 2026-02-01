# s3grep

Search through S3 files without downloading them.

## Installation

```bash
gem install s3grep
```

Or add to your Gemfile:

```ruby
gem 's3grep'
```

## CLI Tools

### s3grep

Search for a pattern in S3 files. Supports gzip and zip compressed files automatically.

```bash
# Basic search
s3grep "pattern" s3://bucket-name/path/to/file.csv

# Case-insensitive search
s3grep -i "pattern" s3://bucket-name/path/to/file.csv

# Recursive search through a directory
s3grep -r "pattern" s3://bucket-name/path/to/directory/

# Recursive search with file pattern filter
s3grep -r --include "\.csv$" "pattern" s3://bucket-name/logs/

# Search compressed files (auto-detected)
s3grep "error" s3://bucket-name/logs/app.log.gz
```

Output format: `s3://bucket/path/file:line_number content`

### s3cat

Stream S3 file contents to stdout.

```bash
# Print file contents
s3cat s3://bucket-name/path/to/file.txt

# Pipe to other commands
s3cat s3://bucket-name/data.csv | head -20

# Use with standard unix tools
s3cat s3://bucket-name/users.json | jq '.users[]'
```

### s3info

Get statistics about an S3 directory as JSON.

```bash
# Get info for a prefix
s3info s3://bucket-name/path/to/directory/
```

Output includes:
- `bucket` - Bucket name
- `base_prefix` - S3 prefix path
- `total_size` - Total bytes across all files
- `num_files` - File count
- `last_modified` / `newest_file` - Most recently modified file
- `first_modified` / `first_file` - Oldest file
- `num_files_by_storage_class` - File count breakdown by storage class
- `total_size_by_storage_class` - Size breakdown by storage class

Example output:
```json
{
  "bucket": "my-bucket",
  "base_prefix": "logs/2024/",
  "total_size": 1048576000,
  "num_files": 365,
  "last_modified": "2024-12-31T23:59:59+00:00",
  "newest_file": "logs/2024/12/31/app.log",
  "first_modified": "2024-01-01T00:00:00+00:00",
  "first_file": "logs/2024/01/01/app.log",
  "num_files_by_storage_class": {
    "STANDARD": 100,
    "STANDARD_IA": 265
  },
  "total_size_by_storage_class": {
    "STANDARD": 500000000,
    "STANDARD_IA": 548576000
  }
}
```

### s3report

Generate a CSV report of all S3 buckets in your AWS account.

```bash
s3report
```

Creates a file named `AWS-S3-Usage-Report-YYYY-MM-DDTHHMMSS.csv` with columns:
- Bucket
- Creation Date
- Total Size
- Number of Files
- Last Modified
- Newest File
- First Modified
- First File

## AWS Configuration

Authentication uses the standard AWS SDK credential chain:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. IAM instance profile (EC2/ECS)

Set your region via `AWS_REGION` environment variable or `~/.aws/config`.

Use `AWS_PROFILE` to select a named profile:

```bash
AWS_PROFILE=stage s3grep "error" s3://my-bucket/logs/app.log
```

## License

MIT
