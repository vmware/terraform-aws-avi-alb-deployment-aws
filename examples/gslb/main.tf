# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 0.13.6"
  backend "local" {
  }
}

module "avi_controller_aws_west2" {
  source = "../.."

  region                    = "us-west-2"
  aws_access_key            = var.aws_access_key
  aws_secret_key            = var.aws_secret_key
  controller_ha             = var.controller_ha
  controller_public_address = var.controller_public_address
  create_networking         = var.create_networking
  create_iam                = var.create_iam
  avi_version               = var.avi_version
  custom_vpc_id             = var.custom_vpc_id_west
  custom_subnet_ids         = var.custom_subnet_ids_west
  avi_cidr_block            = var.avi_cidr_block_west
  controller_password       = var.controller_password
  key_pair_name             = var.key_pair_name
  private_key_path          = var.private_key_path
  name_prefix               = var.name_prefix_west
  configure_dns_profile     = { enabled = "true", type = "AVI", usable_domains = ["west2.avidemo.net"] }
  configure_dns_vs          = var.configure_dns_vs_west
  configure_gslb            = { enabled = "false", site_name = "West2" }
}
module "avi_controller_aws_east2" {
  source = "../.."

  region                    = "us-east-2"
  aws_access_key            = var.aws_access_key
  aws_secret_key            = var.aws_secret_key
  controller_ha             = var.controller_ha
  controller_public_address = var.controller_public_address
  create_networking         = var.create_networking
  create_iam                = var.create_iam
  avi_version               = var.avi_version
  custom_vpc_id             = var.custom_vpc_id_east
  custom_subnet_ids         = var.custom_subnet_ids_east
  avi_cidr_block            = var.avi_cidr_block_east
  controller_password       = var.controller_password
  key_pair_name             = var.key_pair_name
  private_key_path          = var.private_key_path
  name_prefix               = var.name_prefix_east
  configure_dns_profile     = { enabled = "true", type = "AVI", usable_domains = ["east2.avidemo.net"] }
  configure_dns_vs          = var.configure_dns_vs_east
  configure_gslb            = { enabled = "true", leader = "true", site_name = "East2", domains = ["gslb.avidemo.net"], additional_sites = [{ name = "West2", ip_address_list = module.avi_controller_aws_west2.controllers[*].private_ip_address }] }
}