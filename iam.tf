# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_iam_role" "vmimport" {
  count              = var.create_iam ? (local.check_for_vmimport_iam_role != 1 || local.check_vmimport_tags == 1) ? 1 : 0 : 0
  name               = "vmimport"
  assume_role_policy = file("${path.module}/files/iam/vmimport-role-trust.json")

  tags = local.tags
  lifecycle {
    ignore_changes = [
      permissions_boundary
    ]
  }
}
resource "aws_iam_role" "avi" {
  count              = var.create_iam ? 1 : 0
  name               = "${var.name_prefix}_AviController-Refined-Role"
  assume_role_policy = file("${path.module}/files/iam/avicontroller-role-trust.json")

  tags = var.custom_tags
  lifecycle {
    ignore_changes = [
      permissions_boundary
    ]
  }
}
resource "aws_iam_instance_profile" "avi" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}_avi_instance_profile"
  role  = aws_iam_role.avi[0].id
}
resource "aws_iam_role_policy" "avi_vmimport_policy" {
  count = var.create_iam ? (local.check_for_vmimport_iam_role != 1 || local.check_vmimport_tags == 1) ? 1 : 0 : 0
  name  = "${var.name_prefix}-avi-vmimport-policy"
  role  = aws_iam_role.vmimport[0].id

  policy = templatefile("${path.module}/files/iam/vmimport-role-policy.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_vmimport_kms_policy" {
  count = var.create_iam ? (local.check_for_vmimport_iam_role != 1 || local.check_vmimport_tags == 1) ? 1 : 0 : 0
  name  = "${var.name_prefix}-avicontroller-kms-vmimport-policy"
  role  = aws_iam_role.vmimport[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-kms-vmimport.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_ec2" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-ec2-policy"
  role  = aws_iam_role.avi[0].id

  policy = file("${path.module}/files/iam/avicontroller-ec2-policy.json")
}
resource "aws_iam_role_policy" "avi_iam" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-iam-policy"
  role  = aws_iam_role.avi[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-iam-policy.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_s3" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-s3-policy"
  role  = aws_iam_role.avi[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-s3-policy.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_r53" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-r53-policy"
  role  = aws_iam_role.avi[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-r53-policy.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_autoscaling" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-asg-policy"
  role  = aws_iam_role.avi[0].id

  policy = file("${path.module}/files/iam/avicontroller-asg-policy.json")
}
resource "aws_iam_role_policy" "avi_sqs_sns" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-sqs-sns-policy"
  role  = aws_iam_role.avi[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-sqs-sns-policy.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_kms" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-kms-policy"
  role  = aws_iam_role.avi[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-kms-policy.json.tpl", { awsPartition = data.aws_partition.current.partition })
}
resource "aws_iam_role_policy" "avi_s3_backup" {
  count = var.create_iam ? 1 : 0
  name  = "${var.name_prefix}-avicontroller-s3-backup-policy"
  role  = aws_iam_role.avi[0].id

  policy = templatefile("${path.module}/files/iam/avicontroller-s3-backup-policy.json.tpl", { awsPartition = data.aws_partition.current.partition, s3_bucket = aws_s3_bucket.s3_nsxalb_backups.id })
}
