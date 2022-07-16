# Copyright 2021 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

output "controllers" {
  description = "Avi Controller IP Address"
  value       = module.avi_controller_aws.controllers
}
