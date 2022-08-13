# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

variable "region" {
  description = "The Region that the AVI controller and SEs will be deployed to"
  type        = string
}
variable "aws_access_key" {
  description = "The Access Key that will be used to deploy AWS resources"
  type        = string
  sensitive   = false
}
variable "aws_secret_key" {
  description = "The Secret Key that will be used to deploy AWS resources"
  type        = string
  sensitive   = false
}
variable "key_pair_name" {
  description = "The name of the existing EC2 Key pair that will be used to authenticate to the Avi Controller"
  type        = string
}
variable "private_key_path" {
  description = "The local private key path for the EC2 Key pair used for authenticating to the Avi Controller"
  type        = string
  sensitive   = false
}
variable "avi_version" {
  description = "The AVI Controller version that will be deployed"
  type        = string
}
variable "avi_upgrade" {
  description = "This variable determines if a patch upgrade is performed after install. The enabled key should be set to true and the url from the Avi Cloud Services portal for the should be set for the upgrade_file_uri key. Valid upgrade_type values are patch or system"
  sensitive   = false
  type        = object({ enabled = bool, upgrade_type = string, upgrade_file_uri = string })
  default     = { enabled = "false", upgrade_type = "patch", upgrade_file_uri = "" }
}
variable "name_prefix" {
  description = "This prefix is appended to the names of the Controller and SEs"
  type        = string
}
variable "controller_ha" {
  description = "If true a HA controller cluster is deployed and configured"
  type        = bool
  default     = "false"
}
variable "register_controller" {
  description = "If enabled is set to true the controller will be registered and licensed with Avi Cloud Services. The Long Organization ID (organization_id) can be found from https://console.cloud.vmware.com/csp/gateway/portal/#/organization/info. The jwt_token can be retrieved at https://portal.avipulse.vmware.com/portal/controller/auth/cspctrllogin"
  sensitive   = false
  type        = object({ enabled = bool, jwt_token = string, email = string, organization_id = string })
  default     = { enabled = "false", jwt_token = "", email = "", organization_id = "" }
}
variable "create_networking" {
  description = "This variable controls the VPC and subnet creation for the AVI Controller. When set to false the custom-vpc-name and custom-subnetwork-name must be set."
  type        = bool
  default     = "true"
}
variable "create_firewall_rules" {
  description = "This variable controls the Security Group creation for the Avi deployment. When set to false the necessary security group rules must be in place before the deployment and set with the firewall_custom_security_group_ids variable"
  type        = bool
  default     = "true"
}
variable "firewall_controller_allow_source_range" {
  description = "The IP range allowed to connect to the Avi Controller. Access from all IP ranges will be allowed by default"
  type        = string
  default     = "0.0.0.0/0"
}
variable "firewall_controller_security_group_ids" {
  description = "List of security group IDs that will be assigned to the controller. This variable must be set if the create_firewall_rules variable is set to false"
  type        = list(string)
  default     = null
}
variable "firewall_se_data_rules" {
  description = "The data plane traffic allowed for Virtual Services hosted on Services Engines. The configure_firewall_rules variable must be set to true for these rules to be created"
  type        = list(object({ protocol = string, port = string, allow_ip_range = string, description = string }))
  default     = [{ protocol = "tcp", port = "443", allow_ip_range = "0.0.0.0/0", description = "https" }, { protocol = "udp", port = "53", allow_ip_range = "10.0.0.0/8", description = "DNS" }]
}
variable "controller_public_address" {
  description = "This variable controls if the Controller has a Public IP Address. When set to false the Ansible provisioner will connect to the private IP of the Controller."
  type        = bool
  default     = "false"
}
variable "avi_cidr_block" {
  description = "This CIDR that will be used for creating a subnet in the AVI VPC - a /16 should be provided. This range is also used for security group rules source IP range for internal communication between the Controllers and SEs"
  type        = string
  default     = "10.255.0.0/16"
}
variable "custom_vpc_id" {
  description = "This field can be used to specify an existing VPC for the controller and SEs. The create-networking variable must also be set to false for this network to be used."
  type        = string
  default     = null
}
variable "custom_subnet_ids" {
  description = "This field can be used to specify a list of existing VPC Subnets for the controller and SEs. The create-networking variable must also be set to false for this network to be used."
  type        = list(string)
  default     = null
}
variable "create_iam" {
  description = "Create IAM policy, roles, and instance profile for Avi AWS Full Access Cloud. If set to false the aws_access_key and aws_secret_key variables will be used for the Cloud configuration and all policy must be created as found in https://avinetworks.com/docs/latest/iam-role-setup-for-installation-into-aws/"
  type        = bool
  default     = "true"
}
variable "controller_password" {
  description = "The password that will be used authenticating with the AVI Controller. This password be a minimum of 8 characters and contain at least one each of uppercase, lowercase, numbers, and special characters"
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.controller_password) > 7
    error_message = "The controller_password value must be more than 8 characters and contain at least one each of uppercase, lowercase, numbers, and special characters."
  }
}
variable "instance_type" {
  description = "The EC2 instance type for the Avi Controller"
  type        = string
  default     = "m5.2xlarge"
}
variable "boot_disk_size" {
  description = "The boot disk size for the Avi controller"
  type        = number
  default     = 128
  validation {
    condition     = var.boot_disk_size >= 128
    error_message = "The Controller root disk size should be greater than or equal to 128 GB."
  }
}
variable "se_ha_mode" {
  description = "The HA mode of the default Service Engine Group. Possible values active/active, n+m, or active/standby"
  type        = string
  default     = "active/active"
  validation {
    condition     = contains(["active/active", "n+m", "active/standby"], var.se_ha_mode)
    error_message = "Acceptable values are active/active, n+m, or active/standby."
  }
}
variable "se_instance_type" {
  description = "The instance type of the default Service Engine Group. Possible values can be found at https://aws.amazon.com/ec2/instance-types/"
  type        = string
  default     = "c5.large"
}
variable "custom_tags" {
  description = "Custom tags added to AWS Resources created by the module"
  type        = map(string)
  default     = {}
}
variable "dns_servers" {
  description = "The optional DNS servers that will be used for local DNS resolution by the controller. Example [\"8.8.4.4\", \"8.8.8.8\"]"
  type        = list(string)
  default     = null
}
variable "dns_search_domain" {
  description = "The optional DNS search domain that will be used by the controller"
  type        = string
  default     = null
}
variable "ntp_servers" {
  description = "The NTP Servers that the Avi Controllers will use. The server should be a valid IP address (v4 or v6) or a DNS name. Valid options for type are V4, DNS, or V6"
  type        = list(object({ addr = string, type = string }))
  default     = [{ addr = "0.us.pool.ntp.org", type = "DNS" }, { addr = "1.us.pool.ntp.org", type = "DNS" }, { addr = "2.us.pool.ntp.org", type = "DNS" }, { addr = "3.us.pool.ntp.org", type = "DNS" }]
}
variable "email_config" {
  description = "The Email settings that will be used for sending password reset information or for trigged alerts. The default setting will send emails directly from the Avi Controller"
  sensitive   = false
  type        = object({ smtp_type = string, from_email = string, mail_server_name = string, mail_server_port = string, auth_username = string, auth_password = string })
  default     = { smtp_type = "SMTP_LOCAL_HOST", from_email = "admin@avicontroller.net", mail_server_name = "localhost", mail_server_port = "25", auth_username = "", auth_password = "" }
}
variable "configure_cloud" {
  description = "Configure the Avi Cloud via Ansible after controller deployment. If not set to true this must be done manually with the desired config"
  type        = bool
  default     = "true"
}
variable "configure_dns_profile" {
  description = "Configure Avi DNS Profile for DNS Record Creation for Virtual Services. If set to true the dns_service_domain variable must also be set"
  type        = bool
  default     = "false"
}
variable "configure_dns_route_53" {
  description = "Configures Avi Cloud with Route53 DNS Provider. The following variables must be set to false if enabled: configure_dns_profile, configure_dns_vs, configure_gslb"
  type        = bool
  default     = "false"
}
variable "configure_dns_vs" {
  description = "Create Avi DNS Virtual Service. The configure_dns_profile variable must also be set to true"
  type        = bool
  default     = "false"
}
variable "dns_vs_settings" {
  description = "Settings for the DNS Virtual Service. The subnet_name must be an existing AWS Subnet. If the allocate_public_ip option is set to true a EIP will be allocated for the VS. The VS IP address will automatically be allocated via the AWS IPAM. Example:{ subnet_name = \"subnet-dns\", allocate_public_ip = \"true\" }"
  type        = object({ subnet_name = string, allocate_public_ip = bool })
  default     = null
}
variable "dns_service_domain" {
  description = "The DNS Domain that will be available for Virtual Services. Avi will be the Authorative Nameserver for this domain and NS records may need to be created pointing to the Avi Service Engine addresses. An example is demo.Avi.com"
  type        = string
  default     = ""
}
variable "configure_gslb" {
  description = "Configure GSLB. The gslb_site_name, gslb_domains, and configure_dns_vs variables must also be set. Optionally the additional_gslb_sites variable can be used to add active GSLB sites"
  type        = bool
  default     = "false"
}
variable "gslb_site_name" {
  description = "The name of the GSLB site the deployed Controller(s) will be a member of."
  type        = string
  default     = ""
}
variable "gslb_domains" {
  description = "A list of GSLB domains that will be configured"
  type        = list(string)
  default     = [""]
}
variable "configure_gslb_additional_sites" {
  description = "Configure additional GSLB Sites. The additional_gslb_sites, gslb_site_name, gslb_domains, and configure_dns_vs variables must also be set"
  type        = bool
  default     = "false"
}
variable "additional_gslb_sites" {
  description = "The Names and IP addresses of the GSLB Sites that will be configured. If the Site is a controller cluster the ip_address_list should have the ip address of each controller. The configure_gslb_additional_sites variable must also be set to true for the sites to be added"
  type        = list(object({ name = string, ip_address_list = list(string), dns_vs_name = string }))
  default     = [{ name = "", ip_address_list = [""], dns_vs_name = "DNS-VS" }]
}
variable "create_gslb_se_group" {
  description = "Create a SE group for GSLB. The gslb_site_name variable must also be configured. This variable should be set to true for the follower GSLB sites. When configure_gslb is set to true a SE group will be created automatically"
  type        = bool
  default     = "false"
}
variable "gslb_se_instance_type" {
  description = "The instance_type of the GSLB Service Engine group. The default is 2 vCPU, 8 GB RAM, and a 30 GB Disk per Service Engine. Syntax [\"cpu_cores\", \"memory_in_GB\", \"disk_size_in_GB\"]"
  type        = string
  default     = "c5.xlarge"
}