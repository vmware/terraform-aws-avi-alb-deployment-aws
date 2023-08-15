resource "aws_s3_bucket" "s3_nsxalb_backups" {
  bucket = var.s3_backup_bucket
}

resource "aws_s3_bucket_public_access_block" "s3_nsxalb_backups" {
  bucket = aws_s3_bucket.s3_nsxalb_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "s3_nsxalb_backups" {
  bucket = aws_s3_bucket.s3_nsxalb_backups.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "s3_nsxalb_backups" {
  bucket = aws_s3_bucket.s3_nsxalb_backups.id
  rule {
    id = "Backup Retention"
    expiration {
      days = var.s3_backup_retention
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_nsxalb_backups" {
  bucket = aws_s3_bucket.s3_nsxalb_backups.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.se_s3_encryption_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}
