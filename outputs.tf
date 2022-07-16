# Copyright 2021 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

output "controllers" {
  description = "The AVI Controller(s) Information"
  value = ([for s in aws_instance.avi_controller : merge(
    { "name" = s.tags.Name },
    { "private_ip_address" = s.private_ip },
    var.controller_public_address ? { "public_ip_address" = s.public_ip } : {}
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