# Architecture

## Overview

s3grep is a Ruby gem providing grep-like functionality for AWS S3 objects. It streams files directly from S3 without downloading them locally, enabling efficient searching of large files.

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLI Layer (bin/)                        │
├──────────┬──────────┬──────────────┬───────────────────────────┤
│  s3grep  │  s3cat   │    s3info    │         s3report          │
│ (search) │ (stream) │ (dir stats)  │    (bucket inventory)     │
└────┬─────┴────┬─────┴──────┬───────┴─────────────┬─────────────┘
     │          │            │                     │
     ▼          ▼            ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      S3Grep Module (lib/)                       │
├─────────────────────┬───────────────────┬───────────────────────┤
│       Search        │     Directory     │    DirectoryInfo      │
│  (file streaming)   │  (object listing) │  (stats aggregation)  │
└──────────┬──────────┴─────────┬─────────┴───────────┬───────────┘
           │                    │                     │
           ▼                    ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                       AWS SDK (aws-sdk-s3)                      │
│              get_object  │  list_objects  │  list_buckets       │
└─────────────────────────────────────────────────────────────────┘
```

## Core Classes

### S3Grep::Search

Streams an S3 object and performs line-by-line regex matching.

**Responsibilities:**
- Parse S3 URL to extract bucket and key
- Stream object content via `get_object`
- Auto-detect and decompress .gz and .zip files
- Yield matching lines with line numbers

**Key Methods:**
- `Search.search(s3_url, client, regex)` - Class method for simple searches
- `Search.detect_compression(s3_url)` - Infers compression from file extension
- `#to_io` - Returns readable IO (decompressed if needed)

### S3Grep::Directory

Lists objects in an S3 prefix with optional glob-style filtering.

**Responsibilities:**
- Parse S3 URL to extract bucket and prefix
- Handle pagination (1000 objects per request)
- URL-encode/decode object keys with special characters
- Support regex filtering via `glob` method

**Key Methods:**
- `Directory.glob(s3_url, client, regex)` - List objects matching pattern
- `#each` - Iterate full S3 URLs for all objects
- `#each_content` - Iterate raw S3 object metadata (for DirectoryInfo)
- `#info` - Factory method returning DirectoryInfo

### S3Grep::DirectoryInfo

Aggregates statistics while iterating through directory contents.

**Responsibilities:**
- Count files and total size
- Track newest/oldest files by modification date
- Breakdown counts and sizes by storage class

**Key Methods:**
- `DirectoryInfo.get(directory)` - Process directory and return populated info
- `#last_modified` / `#first_modified` - Timestamp accessors
- `#newest_file` / `#first_file` - Key accessors

## Data Flow

### Search Flow (s3grep)

```
User Input: regex + s3://bucket/key
       │
       ▼
┌──────────────┐
│ Parse S3 URL │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ Detect compression   │
│ (.gz, .zip, or none) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ aws_s3_client        │
│   .get_object()      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Wrap in GzipReader   │
│ or Zip::File if      │
│ compressed           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Stream lines,        │
│ yield matches with   │
│ line numbers         │
└──────────────────────┘
```

### Directory Listing Flow (s3info, recursive s3grep)

```
User Input: s3://bucket/prefix/
       │
       ▼
┌──────────────────────┐
│ list_objects         │
│ (max_keys: 1000)     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ More results?        │──No──▶ Done
│ (size == max_keys)   │
└──────────┬───────────┘
           │ Yes
           ▼
┌──────────────────────┐
│ list_objects with    │
│ marker = last key    │
└──────────┬───────────┘
           │
           └───────▶ (repeat until exhausted)
```

## AWS Integration

### Authentication
Uses the AWS SDK default credential chain:
1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. IAM instance profile (EC2/ECS)

### Region Handling
- Default client uses `AWS_REGION` or `~/.aws/config`
- `s3report` creates region-specific clients per bucket via `get_bucket_location`

### S3 URL Format
All tools expect: `s3://bucket-name/path/to/prefix`
- Host = bucket name
- Path = object key or prefix (URL-decoded internally)

## Compression Support

| Extension | Library | Notes |
|-----------|---------|-------|
| `.gz` | zlib (stdlib) | GzipReader wraps body IO |
| `.zip` | rubyzip | Reads first entry only |
| (none) | - | Raw body IO |
