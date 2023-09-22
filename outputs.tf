# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

output "controllers" {
  description = "The AVI Controller(s) Information"
  value = (var.controller_public_address ? [for s in aws_eip.avi :
    { "name" = s.tags.Name, "private_ip_address" = s.private_ip, "public_ip_address" = s.public_ip }
    ] : [for s in aws_instance.avi_controller : merge(
      { "name" = s.tags.Name },
      { "private_ip_address" = s.private_ip }
    )
    ]
  )
}
output "controller_private_addresses" {
  description = "The Private IP Addresses allocated for the Avi Controller(s)"
  value       = aws_instance.avi_controller[*].private_ip
}
output "controller_public_addresses" {
  description = "Public IP Addresses for the AVI Controller(s)"
  value       = aws_instance.avi_controller[*].public_ip
}

output "controller_security_group_id" {
  description = "Security Group associated with Avi Controller(s)"
  value       = (var.create_firewall_rules ? aws_security_group.avi_controller_sg[0].id : null)
}

output "service_engine_avi_mgmt_security_group_id" {
  description = "Security Group associated with Avi Service Engines for management traffic"
  value       = (var.create_firewall_rules ? aws_security_group.avi_se_mgmt_sg[0].id : null)
}

output "service_engine_avi_data_security_group_id" {
  description = "Security Group associated with Avi Service Engines for data traffic"
  value       = (var.create_firewall_rules ? aws_security_group.avi_data_sg[0].id : null)
}
