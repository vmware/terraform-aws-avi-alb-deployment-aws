# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

data "aws_availability_zones" "azs" {
  state = "available"
}
data "aws_subnet" "custom" {
  for_each = toset(var.custom_subnet_ids)
  id       = each.value
}
data "aws_ami" "avi" {
  count = var.custom_ami == null ? 1 : 0
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["Avi*Controller-${var.avi_version}-*"]
  }
}
data "aws_iam_roles" "vmimport" {
  count      = var.create_iam ? 1 : 0
  name_regex = "^vmimport$"
}
data "aws_iam_role" "vmimport" {
  count = var.create_iam ? length(data.aws_iam_roles.vmimport[0].names) : 0
  name  = "vmimport"
}
data "aws_kms_alias" "s3" {
  count = var.se_s3_encryption ? 1 : 0
  name  = "alias/aws/s3"
}
data "aws_kms_alias" "ebs" {
  count = var.controller_ebs_encryption || var.se_ebs_encryption ? 1 : 0
  name  = "alias/aws/ebs"
}
data "aws_partition" "current" {}
