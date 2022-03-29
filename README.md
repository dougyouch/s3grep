# s3grep

Search through S3 files without downloading them.

# Basic Usage

Search for a pattern in a S3 file.

example:
```
s3grep Bob s3://exammple.com/users.csv
```

Outputs S3 file with line number and the matching line.
