# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # Ansible Settings
  cloud_settings = {
    create_iam                = var.create_iam
    create_firewall_rules     = var.create_firewall_rules
    se_mgmt_subnets           = var.create_networking ? local.mgmt_subnets : local.custom_mgmt_subnets
    vpc_id                    = var.create_networking ? aws_vpc.avi[0].id : var.custom_vpc_id
    aws_partition             = data.aws_partition.current.partition
    aws_region                = var.region
    avi_version               = var.avi_version
    dns_servers               = var.dns_servers
    dns_search_domain         = var.dns_search_domain
    ntp_servers               = var.ntp_servers
    email_config              = var.email_config
    name_prefix               = var.name_prefix
    mgmt_security_group       = var.create_firewall_rules ? aws_security_group.avi_se_mgmt_sg[0].id : ""
    data_security_group       = var.create_firewall_rules ? aws_security_group.avi_data_sg[0].id : ""
    controller_ha             = var.controller_ha
    register_controller       = var.register_controller
    controller_ip             = local.controller_ip
    controller_names          = local.controller_names
    configure_dns_route_53    = var.configure_dns_route_53
    configure_dns_profile     = var.configure_dns_profile
    configure_dns_vs          = var.configure_dns_vs
    configure_gslb            = var.configure_gslb
    se_ha_mode                = var.se_ha_mode
    se_instance_type          = var.se_instance_type
    se_ebs_encryption_key_arn = var.se_ebs_encryption ? var.se_ebs_encryption_key_arn == null ? data.aws_kms_alias.ebs[0].target_key_arn : var.se_ebs_encryption_key_arn : null
    se_s3_encryption_key_arn  = var.se_ebs_encryption ? var.se_s3_encryption_key_arn == null ? data.aws_kms_alias.s3[0].target_key_arn : var.se_s3_encryption_key_arn : null
    avi_upgrade               = var.avi_upgrade
    license_tier              = var.license_tier
    license_key               = var.license_key
    portal_certificate        = var.portal_certificate
    securechannel_certificate = var.securechannel_certificate
    ca_certificates           = var.ca_certificates
    s3_backup_bucket          = aws_s3_bucket.s3_nsxalb_backups.id
  }
  controller_names = aws_instance.avi_controller[*].tags.Name
  controller_ip    = aws_instance.avi_controller[*].private_ip
  private_key      = var.private_key_path != null ? file(var.private_key_path) : var.private_key_contents

  mgmt_subnets = { for subnet in aws_subnet.avi : subnet.availability_zone =>
    {
      "mgmt_network_uuid" = subnet.id
      "mgmt_network_name" = subnet.tags["Name"]
    }
  }
  custom_mgmt_subnets = { for subnet in data.aws_subnet.custom : subnet.availability_zone =>
    {
      "mgmt_network_uuid" = subnet.id
      "mgmt_network_name" = subnet.tags["Name"]
    }
  }
  az_names = data.aws_availability_zones.azs.names
  tags = merge(
    var.custom_tags,
    {
      terraform_module = "vmware/avi-alb-deployment-aws/aws"
    },
  )
  check_for_vmimport_iam_role = var.create_iam ? length(data.aws_iam_roles.vmimport[0].names) : null
  check_vmimport_tag_key      = can(data.aws_iam_role.vmimport[0].tags["terraform_module"])
  check_vmimport_tags         = var.create_iam && length(data.aws_iam_roles.vmimport[0].names) == 1 && local.check_vmimport_tag_key ? data.aws_iam_role.vmimport[0].tags["terraform_module"] == "vmware/avi-alb-deployment-aws/aws" ? 1 : null : null
}

resource "aws_instance" "avi_controller" {
  count = var.controller_ha ? 3 : 1
  ami   = var.custom_ami == null ? data.aws_ami.avi[0].id : var.custom_ami
  root_block_device {
    volume_size           = var.boot_disk_size
    delete_on_termination = true
    encrypted             = var.controller_ebs_encryption
    kms_key_id            = var.controller_ebs_encryption ? var.controller_ebs_encryption_key_arn == null ? data.aws_kms_alias.ebs[0].target_key_arn : var.controller_ebs_encryption_key_arn : null
  }
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = var.create_networking ? aws_subnet.avi[count.index].id : var.custom_controller_subnet_ids[count.index]
  vpc_security_group_ids      = var.create_firewall_rules ? [aws_security_group.avi_controller_sg[0].id] : var.firewall_controller_security_group_ids
  iam_instance_profile        = var.create_iam ? aws_iam_instance_profile.avi[0].id : null
  associate_public_ip_address = false
  tags = {
    Name = (var.custom_controller_name != null) ? "${var.custom_controller_name}-${count.index + 1}" : "${var.name_prefix}-avi-controller-${count.index + 1}"
  }
  metadata_options {
    # Only supported with AVI versions 22.1.3 and newer
    http_tokens = can(regex("^(?:2[3-9]|[3-9]\\d|\\d{3,})\\.\\d+\\.\\d+$", var.avi_version)) ? "required" : "optional"
  }
  lifecycle {
    ignore_changes = [tags, associate_public_ip_address, root_block_device[0].tags]
  }
}

resource "aws_ec2_tag" "custom_controller_1" {
  for_each    = var.custom_tags
  resource_id = aws_instance.avi_controller[0].id
  key         = each.key
  value       = each.value
}
resource "aws_ec2_tag" "custom_controller_2" {
  for_each    = var.controller_ha ? var.custom_tags : {}
  resource_id = aws_instance.avi_controller[1].id
  key         = each.key
  value       = each.value
}
resource "aws_ec2_tag" "custom_controller_3" {
  for_each    = var.controller_ha ? var.custom_tags : {}
  resource_id = aws_instance.avi_controller[2].id
  key         = each.key
  value       = each.value
}
resource "null_resource" "changepassword_provisioner" {
  count = var.controller_ha ? 3 : 1
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    controller_instance_ids = join(",", aws_instance.avi_controller[*].id)
  }
  lifecycle {
    precondition {
      condition     = local.private_key != null
      error_message = "Must provide a value for either private_key_path or private_key_contents."
    }
  }
  connection {
    type        = "ssh"
    host        = var.controller_public_address ? aws_eip.avi[count.index].public_ip : aws_instance.avi_controller[count.index].private_ip
    user        = "admin"
    timeout     = "600s"
    private_key = local.private_key
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 180",
      "sudo /opt/avi/scripts/initialize_admin_user.py --password ${var.controller_password}",
      "mkdir ansible"
    ]
  }

}
resource "null_resource" "ansible_provisioner" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    controller_instance_ids = join(",", aws_instance.avi_controller[*].id)
  }
  depends_on = [null_resource.changepassword_provisioner]
  lifecycle {
    precondition {
      condition     = local.private_key != null
      error_message = "Must provide a value for either private_key_path or private_key_contents."
    }
  }
  connection {
    type        = "ssh"
    host        = var.controller_public_address ? aws_eip.avi[0].public_ip : aws_instance.avi_controller[0].private_ip
    user        = "admin"
    timeout     = "600s"
    private_key = local.private_key
  }
  provisioner "file" {
    source      = "${path.module}/files/ansible/avi_pulse_registration.py"
    destination = "/home/admin/ansible/avi_pulse_registration.py"
  }
  provisioner "file" {
    source      = "${path.module}/files/ansible/views_albservices.patch"
    destination = "/home/admin/ansible/views_albservices.patch"
  }
  provisioner "file" {
    content = templatefile("${path.module}/files/ansible/avi-controller-aws-all-in-one-play.yml.tpl",
    local.cloud_settings)
    destination = "/home/admin/ansible/avi-controller-aws-all-in-one-play.yml"
  }
  provisioner "file" {
    content = templatefile("${path.module}/files/ansible/gslb-add-site-tasks.yml.tpl",
    local.cloud_settings)
    destination = "/home/admin/ansible/gslb-add-site-tasks.yml"
  }
  provisioner "file" {
    content = templatefile("${path.module}/files/ansible/avi-cloud-services-registration.yml.tpl",
    local.cloud_settings)
    destination = "/home/admin/ansible/avi-cloud-services-registration.yml"
  }
  provisioner "file" {
    content = templatefile("${path.module}/files/ansible/avi-upgrade.yml.tpl",
    local.cloud_settings)
    destination = "/home/admin/ansible/avi-upgrade.yml"
  }
  provisioner "file" {
    content = templatefile("${path.module}/files/ansible/avi-cleanup.yml.tpl",
    local.cloud_settings)
    destination = "/home/admin/ansible/avi-cleanup.yml"
  }
  provisioner "remote-exec" {
    inline = var.configure_controller ? var.create_iam ? [
      "sleep 30",
      "export ANSIBLE_COLLECTIONS_PATHS=/etc/ansible/collections:/home/admin/.ansible/collections:/usr/share/ansible/collections",
      "cd ansible",
      "ansible-playbook avi-controller-aws-all-in-one-play.yml -e password=${var.controller_password} 2> ansible-error.log | tee ansible-playbook.log",
      "echo Controller Configuration Completed"
      ] : [
      "sleep 30",
      "export ANSIBLE_COLLECTIONS_PATHS=/etc/ansible/collections:/home/admin/.ansible/collections:/usr/share/ansible/collections",
      "cd ansible",
      "ansible-playbook avi-controller-aws-all-in-one-play.yml -e password=${var.controller_password} -e aws_access_key_id=${var.aws_access_key} -e aws_secret_access_key=${var.aws_secret_key} 2> ansible-error.log | tee ansible-playbook.log",
      "echo Controller Configuration Completed"
      ] : [
      "sleep 30",
      "export ANSIBLE_COLLECTIONS_PATHS=/etc/ansible/collections:/home/admin/.ansible/collections:/usr/share/ansible/collections",
      "cd ansible",
      "ansible-playbook avi-controller-aws-all-in-one-play.yml -e password=${var.controller_password} --tags register_controller 2> ansible-error.log | tee ansible-playbook.log",
      "echo Controller Configuration Completed"
    ]
  }
  provisioner "remote-exec" {
    inline = var.register_controller["enabled"] ? [
      "cd ansible",
      "export ANSIBLE_COLLECTIONS_PATHS=/etc/ansible/collections:/home/admin/.ansible/collections:/usr/share/ansible/collections",
      "ansible-playbook avi-cloud-services-registration.yml -e password=${var.controller_password} 2>> ansible-error.log | tee -a ansible-playbook.log",
      "echo Controller Registration Completed"
    ] : ["echo Controller Registration Skipped"]
  }
  provisioner "remote-exec" {
    inline = var.avi_upgrade["enabled"] ? [
      "cd ansible",
      "export ANSIBLE_COLLECTIONS_PATHS=/etc/ansible/collections:/home/admin/.ansible/collections:/usr/share/ansible/collections",
      "ansible-playbook avi-upgrade.yml -e password=${var.controller_password} -e upgrade_type=${var.avi_upgrade["upgrade_type"]} 2>> ansible-error.log | tee -a ansible-playbook.log",
      "echo Avi upgrade completed"
    ] : ["echo Avi upgrade skipped"]
  }
}