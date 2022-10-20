# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_kms_key" "se_s3_key" {
  count       = var.se_s3_encryption && var.se_s3_encryption_key_arn == null ? 1 : 0
  description = "NSX ALB S3 Encryption Key"
  tags = {
    Name    = "${var.name_prefix}-s3-key"
    Purpose = "NSX ALB S3 Encryption Key"
  }
}

resource "aws_kms_alias" "se_s3_key" {
  count         = length(aws_kms_key.se_s3_key) == 1 ? 1 : 0
  name          = "alias/${var.name_prefix}-s3-key"
  target_key_id = aws_kms_key.se_s3_key[0].key_id
}

resource "aws_kms_key" "se_ebs_key" {
  count       = var.se_ebs_encryption && var.se_ebs_encryption_key_arn == null ? 1 : 0
  description = "NSX ALB AMI EBS Encryption Key"
  tags = {
    Name    = "${var.name_prefix}-ebs-key"
    Purpose = "NSX ALB AMI EBS Encryption Key"
  }
}

resource "aws_kms_alias" "se_ebs_key" {
  count         = length(aws_kms_key.se_ebs_key) == 1 ? 1 : 0
  name          = "alias/${var.name_prefix}-ebs-key"
  target_key_id = aws_kms_key.se_ebs_key[0].key_id
}

