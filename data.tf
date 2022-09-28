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
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["Avi*Controller-${var.avi_version}-*"]
  }
}
data "aws_partition" "current" {}