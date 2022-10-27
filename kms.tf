# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_kms_key" "controller_ebs_key" {
  count       = var.controller_ebs_encryption && var.controller_ebs_encryption_key_arn == null ? 1 : 0
  description = "Avi Controller EBS Encryption Key"
  tags = {
    Name    = "${var.name_prefix}-avicontroller-ebs-key"
    Purpose = "Avi Controller EBS Encryption Key"
  }
}

resource "aws_kms_alias" "controller_ebs_key" {
  count         = length(aws_kms_key.controller_ebs_key) == 1 ? 1 : 0
  name          = "alias/${var.name_prefix}-avicontroller-ebs-key"
  target_key_id = aws_kms_key.controller_ebs_key[0].key_id
}

resource "aws_kms_key" "se_s3_key" {
  count       = var.se_s3_encryption && var.se_s3_encryption_key_arn == null ? 1 : 0
  description = "Avi SE S3 Encryption Key"
  tags = {
    Name    = "${var.name_prefix}-avise-s3-key"
    Purpose = "Avi SE S3 Encryption Key"
  }
}

resource "aws_kms_alias" "se_s3_key" {
  count         = length(aws_kms_key.se_s3_key) == 1 ? 1 : 0
  name          = "alias/${var.name_prefix}-avise-s3-key"
  target_key_id = aws_kms_key.se_s3_key[0].key_id
}

resource "aws_kms_key" "se_ebs_key" {
  count       = var.se_ebs_encryption && var.se_ebs_encryption_key_arn == null ? 1 : 0
  description = "AVI SE AMI EBS Encryption Key"
  tags = {
    Name    = "${var.name_prefix}-avise-ebs-key"
    Purpose = "AVI SE AMI EBS Encryption Key"
  }
}

resource "aws_kms_alias" "se_ebs_key" {
  count         = length(aws_kms_key.se_ebs_key) == 1 ? 1 : 0
  name          = "alias/${var.name_prefix}-avise-ebs-key"
  target_key_id = aws_kms_key.se_ebs_key[0].key_id
}