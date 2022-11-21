# AVI Controller Deployment on AWS Terraform module
This Terraform module creates and configures an AVI (NSX Advanced Load-Balancer) Controller on AWS

## Module Functions
The module is meant to be modular and can create all or none of the prerequiste resources needed for the AVI AWS Deployment including:
* VPC and Subnets for the Controller and SEs (configured with create_networking variable)
* IAM Roles, Policy, and Instance Profile (configured with create_iam variable)
* Security Groups for AVI Controller and SE communication
* AWS EC2 Instance using an official AVI AMI
* High Availability AVI Controller Deployment (configured with controller_ha variable)

During the creation of the Controller instance the following initialization steps are performed:
* Copy Ansible playbook to controller using the assigned public IP
* Run Ansible playbook to configure initial settings and AWS Full Access Cloud

The Ansible playbook can optionally add these configurations:
* Create Avi DNS Profile (configured with the configure_dns_profile variable)
* Create Avi DNS Virtual Service (configured with the configure_dns_vs variable)
* Configure GSLB (configured with the configure_gslb variable)

## Usage
This is an example of a controller deployment that leverages an existing VPC (with a cidr_block of 10.154.0.0/16) and 3 subnets. The public key is already created in EC2 and the private key found in the "/home/user/.ssh/id_rsa" will be used to copy and run the Ansible playbook to configure the Controller.
```hcl
terraform {
  backend "local" {
  }
}
module "avi_controller_aws" {
  source  = "vmware/avi-alb-deployment-aws/aws"
  version = "1.0.x"

  region = "us-west-1"
  create_networking = "false"
  create_iam = "true"
  avi_version = "22.1.1"
  custom_vpc_id = "vpc-<id>"
  custom_subnet_ids = ["subnet-<id>","subnet-<id>","subnet-<id>"]
  avi_cidr_block = "10.154.0.0/16"
  controller_password = "<newpassword>"
  key_pair_name = "<key>"
  private_key_path = "/home/<user>/.ssh/id_rsa"
  name_prefix = "<name>"
  custom_tags = { "Role" : "Avi-Controller", "Owner" : "admin", "Department" : "IT", "shutdown_policy" : "noshut" }
}
output "controller_info" {
  value = module.avi_controller_aws.controllers
}
```
## GSLB Deployment
For GSLB to be configured successfully the configure_gslb and configure_dns_vs variables must be configured. By default a new Service Engine Group (g-dns) and user (gslb-admin) will be created for the configuration. 

The following is a description of the configure_gslb variable parameters and their usage:
| Parameter   | Description | Type |
| ----------- | ----------- | ----------- |
| enabled      | Must be set to "true" for Active GSLB sites | bool
| leader      | Must be set to "true" for only one GSLB site that will be the leader | bool
| site_name   | Name of the GSLB site   | string
| domains   | List of GSLB domains that will be configured | list(string)
| create_se_group | Determines whether a g-dns SE group will be created        | bool
| se_size   | The instance type used for the Avi Service Engines | string
| additional_sites   | Additional sites that will be configured. This parameter should only be set for the primary GSLB site | string

The example below shows a GSLB deployment with 2 regions utilized.
```hcl
terraform {
  backend "local" {
  }
}
provider "aws" {
  alias  = "west2"
  region = "us-west-2"
}
provider "aws" {
  alias  = "east1"
  region = "us-east-1"
}
module "avi_controller_aws_west2" {
  source                = "vmware/avi-alb-deployment-aws/aws"
  providers             = { aws = aws.west2 }
  version               = "1.0.x"

  region                = "us-west-2"
  create_networking     = "false"
  create_iam            = "true"
  controller_ha         = true
  avi_version           = "22.1.2"
  custom_vpc_id         = "vpc-<id>"
  custom_subnet_ids     = ["subnet-<id>","subnet-<id>","subnet-<id>"]
  avi_cidr_block        = "10.154.0.0/16"
  controller_password   = "<newpassword>"
  key_pair_name         = "<key>"
  private_key_path      = "/home/<user>/.ssh/id_rsa"
  name_prefix           = "<name>"
  custom_tags           = { "Role" : "Avi-Controller", "Owner" : "admin", "Department" : "IT" }
  se_ha_mode            = "active/active"
  configure_dns_profile = { enabled = "true", type = "AVI", usable_domains = ["west1.avidemo.net"] }
  configure_dns_vs      = { enabled = "true", allocate_public_ip = "true", subnet_name = "companyname-avi-subnet" }
  configure_gslb        = { enabled = "true", site_name = "West2"}
}
module "avi_controller_aws_east1" {
  source                = "vmware/avi-alb-deployment-aws/aws"
  providers             = { aws = aws.east1 }
  version               = "1.0.x"

  region                = "us-east-1"
  create_networking     = "false"
  create_iam            = "true"
  controller_ha         = true
  avi_version           = "22.1.2"
  custom_vpc_id         = "vpc-<id>"
  custom_subnet_ids     = ["subnet-<id>","subnet-<id>","subnet-<id>"]
  avi_cidr_block        = "10.155.0.0/16"
  controller_password   = "<newpassword>"
  key_pair_name         = "<key>"
  private_key_path      = "/home/<user>/.ssh/id_rsa"
  name_prefix           = "<name>"
  custom_tags           = { "Role" : "Avi-Controller", "Owner" : "admin", "Department" : "IT", "shutdown_policy" : "noshut" }
  se_ha_mode            = "active/active"
  configure_dns_profile = { enabled = "true", type = "AVI", usable_domains = ["east1.avidemo.net"] }
  configure_dns_vs      = { enabled = "true", allocate_public_ip = "true", subnet_name = "companyname-avi-subnet" }
  configure_gslb        = { enabled = "true", leader = "true", site_name = "East1", domains = ["gslb.avidemo.net"], additional_sites = [{name = "West2", ip_address_list = module.avi_controller_aws_west2.controllers[*].private_ip_address}] }
}
output "east1_controller_info" {
  value = module.avi_controller_aws_east1.controllers
}
output "westus2_controller_info" {
  value = module.avi_controller_aws_west2.controllers
}
```
## Day 1 Ansible Configuration and Avi Resource Cleanup
The module copies and runs an Ansible play for configuring the initial day 1 Avi config. The plays listed below can be reviewed by connecting to the Avi Controller by SSH and changing to the ansible folder. In an HA setup the first controller will have these files. 

### avi-controller-aws-all-in-one-play.yml
This play will configure the Avi Cloud, Network, IPAM/DNS profiles, DNS Virtual Service, GSLB depending on the variables used. The initial run of this play will output into the ansible-playbook.log file which can be reviewed to determine what tasks were ran. 

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-controller-aws-all-in-one-play.yml -e password=${var.controller_password} -e aws_access_key_id=${var.aws_access_key} -e aws_secret_access_key=${var.aws_secret_key} > ansible-playbook-run.log
```

### avi-upgrade.yml
This play will upgrade or patch the Avi Controller and SEs depending on the variables used. When ran this play will output into the ansible-playbook.log file which can be reviewed to determine what tasks were ran. This play can be ran during the initial Terraform deployment with the avi_upgrade variable as shown in the example below:

```hcl
avi_upgrade = { enabled = "true", upgrade_type = "patch", upgrade_file_uri = "URL Copied From portal.avipulse.vmware.com"}
```

An full version upgrade can be done by changing changing the upgrade_type to "system". It is recommended to run this play in a lower environment before running in a production environment and is not recommended for a GSLB setup at this time.

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-upgrade.yml -e password=${var.controller_password} -e upgrade_type=${var.avi_upgrade.upgrade_type} -e upgrade_file_uri=${var.avi_upgrade.upgrade_file_uri} > ansible-playbook-run.log
```

### avi-cloud-services-registration.yml
This play will register the Controller with Avi Cloud Services. This can be done to enable centralized licensing, live security threat updates, and proactive support. When ran this play will output into the ansible-playbook.log file which can be reviewed to determine what tasks were ran. This play can be ran during the initial Terraform deployment with the register_controller variable as shown in the example below:

```hcl
register_controller = { enabled = "true", jwt_token = "TOKEN", email = "EMAIL", organization_id = "LONG_ORG_ID" }
```

The organization_id can be found as the Long Organization ID field from https://console.cloud.vmware.com/csp/gateway/portal/#/organization/info.

The jwt_token can be retrieved at https://portal.avipulse.vmware.com/portal/controller/auth/cspctrllogin.

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-cloud-services-registration.yml -e password=${var.controller_password} -e registration_account_id=${var.register_controller.organization_id} -e registration_email=${var.register_controller.email} -e registration_jwt=${var.register_controller.jwt_token} > ansible-playbook-run.log
```

### avi-cleanup.yml
This play will disable all Virtual Services and delete all existing Avi service engines. This playbook should be ran before deleting the controller with terraform destroy to clean up the resources created by the Avi Controller. 

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-cleanup.yml -e password=${var.controller_password}
```
## Contributing

The terraform-aws-avi-alb-deployment-aws project team welcomes contributions from the community. Before you start working with this project please read and sign our Contributor License Agreement (https://cla.vmware.com/cla/1/preview). If you wish to contribute code and you have not signed our Contributor Licence Agreement (CLA), our bot will prompt you to do so when you open a Pull Request. For any questions about the CLA process, please refer to our [FAQ](https://cla.vmware.com/faq). For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.37.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.22.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_tag.custom_controller_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.custom_controller_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.custom_controller_3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_eip.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_instance_profile.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.avi_autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_iam](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_r53](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_sqs_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_vmimport_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.avi_vmimport_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.avi_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route.default_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_security_group.avi_controller_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.avi_data_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.avi_se_mgmt_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [null_resource.ansible_provisioner](https://registry.terraform.io/providers/hashicorp/null/3.2.0/docs/resources/resource) | resource |
| [null_resource.changepassword_provisioner](https://registry.terraform.io/providers/hashicorp/null/3.2.0/docs/resources/resource) | resource |
| [aws_ami.avi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.azs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_kms_alias.ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |
| [aws_kms_alias.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_subnet.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_avi_cidr_block"></a> [avi\_cidr\_block](#input\_avi\_cidr\_block) | This CIDR that will be used for creating a subnet in the AVI VPC - a /16 should be provided. This range is also used for security group rules source IP range for internal communication between the Controllers and SEs | `string` | `"10.255.0.0/16"` | no |
| <a name="input_avi_upgrade"></a> [avi\_upgrade](#input\_avi\_upgrade) | This variable determines if a patch upgrade is performed after install. The enabled key should be set to true and the url from the Avi Cloud Services portal for the should be set for the upgrade\_file\_uri key. Valid upgrade\_type values are patch or system | `object({ enabled = bool, upgrade_type = string, upgrade_file_uri = string })` | <pre>{<br>  "enabled": "false",<br>  "upgrade_file_uri": "",<br>  "upgrade_type": "patch"<br>}</pre> | no |
| <a name="input_avi_version"></a> [avi\_version](#input\_avi\_version) | The AVI Controller version that will be deployed | `string` | n/a | yes |
| <a name="input_aws_access_key"></a> [aws\_access\_key](#input\_aws\_access\_key) | The Access Key that will be used to deploy AWS resources | `string` | `""` | no |
| <a name="input_aws_secret_key"></a> [aws\_secret\_key](#input\_aws\_secret\_key) | The Secret Key that will be used to deploy AWS resources | `string` | `""` | no |
| <a name="input_boot_disk_size"></a> [boot\_disk\_size](#input\_boot\_disk\_size) | The boot disk size for the Avi controller | `number` | `128` | no |
| <a name="input_configure_controller"></a> [configure\_controller](#input\_configure\_controller) | Configure the Avi Cloud via Ansible after controller deployment. If not set to true this must be done manually with the desired config | `bool` | `"true"` | no |
| <a name="input_configure_dns_profile"></a> [configure\_dns\_profile](#input\_configure\_dns\_profile) | Configure a DNS Profile for DNS Record Creation for Virtual Services. The usable\_domains is a list of domains that Avi will be the Authoritative Nameserver for and NS records may need to be created pointing to the Avi Service Engine addresses. Supported profiles for the type parameter are AWS or AVI. The AWS DNS Profile is only needed when the AWS Account used for Route53 is different than the Avi Controller and the configure\_dns\_route\_53 variable can be used otherwise | <pre>object({<br>    enabled        = bool,<br>    type           = optional(string, "AVI"),<br>    usable_domains = list(string),<br>    ttl            = optional(string, "30"),<br>    aws_profile    = optional(object({ iam_assume_role = string, region = string, vpc_id = string, access_key_id = string, secret_access_key = string }))<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "type": "AVI",<br>  "usable_domains": []<br>}</pre> | no |
| <a name="input_configure_dns_route_53"></a> [configure\_dns\_route\_53](#input\_configure\_dns\_route\_53) | Configures Route53 DNS integration in the AWS Cloud configuration. The following variables must be set to false if enabled: configure\_dns\_profile, configure\_dns\_vs, configure\_gslb | `bool` | `"false"` | no |
| <a name="input_configure_dns_vs"></a> [configure\_dns\_vs](#input\_configure\_dns\_vs) | Create Avi DNS Virtual Service. The subnet\_name parameter must be an existing AWS Subnet. If the allocate\_public\_ip parameter is set to true a EIP will be allocated for the VS. The VS IP address will automatically be allocated via the AWS IPAM | `object({ enabled = bool, subnet_name = string, allocate_public_ip = bool })` | <pre>{<br>  "allocate_public_ip": "false",<br>  "enabled": "false",<br>  "subnet_name": ""<br>}</pre> | no |
| <a name="input_configure_gslb"></a> [configure\_gslb](#input\_configure\_gslb) | Configures GSLB. In addition the configure\_dns\_vs variable must also be set for GSLB to be configured. See the GSLB Deployment README section for more information. | <pre>object({<br>    enabled          = bool,<br>    leader           = optional(bool, false),<br>    site_name        = string,<br>    domains          = optional(list(string)),<br>    create_se_group  = optional(bool, true),<br>    se_size          = optional(string, "c5.xlarge"),<br>    additional_sites = optional(list(object({ name = string, ip_address_list = list(string) }))),<br>  })</pre> | <pre>{<br>  "domains": [<br>    ""<br>  ],<br>  "enabled": "false",<br>  "site_name": ""<br>}</pre> | no |
| <a name="input_controller_ebs_encryption"></a> [controller\_ebs\_encryption](#input\_controller\_ebs\_encryption) | Enable encryption on the Controller EBS Root Volume.  The AWS Managed EBS KMS key will be used if no key is provided with the controller\_ebs\_encryption\_key\_arn variable | `bool` | `"true"` | no |
| <a name="input_controller_ebs_encryption_key_arn"></a> [controller\_ebs\_encryption\_key\_arn](#input\_controller\_ebs\_encryption\_key\_arn) | AWS Resource Name of an existing KMS key for the Controller EBS (controller\_ebs\_encryption must be set to true) | `string` | `null` | no |
| <a name="input_controller_ha"></a> [controller\_ha](#input\_controller\_ha) | If true a HA controller cluster is deployed and configured | `bool` | `"false"` | no |
| <a name="input_controller_password"></a> [controller\_password](#input\_controller\_password) | The password that will be used authenticating with the AVI Controller. This password be a minimum of 8 characters and contain at least one each of uppercase, lowercase, numbers, and special characters | `string` | n/a | yes |
| <a name="input_controller_public_address"></a> [controller\_public\_address](#input\_controller\_public\_address) | This variable controls if the Controller has a Public IP Address. When set to false the Ansible provisioner will connect to the private IP of the Controller. | `bool` | `"false"` | no |
| <a name="input_create_firewall_rules"></a> [create\_firewall\_rules](#input\_create\_firewall\_rules) | This variable controls the Security Group creation for the Avi deployment. When set to false the necessary security group rules must be in place before the deployment and set with the firewall\_custom\_security\_group\_ids variable | `bool` | `"true"` | no |
| <a name="input_create_iam"></a> [create\_iam](#input\_create\_iam) | Create IAM policy, roles, and instance profile for Avi AWS Full Access Cloud. If set to false the aws\_access\_key and aws\_secret\_key variables will be used for the Cloud configuration and all policy must be created as found in https://avinetworks.com/docs/latest/iam-role-setup-for-installation-into-aws/ | `bool` | `"true"` | no |
| <a name="input_create_networking"></a> [create\_networking](#input\_create\_networking) | This variable controls the VPC and subnet creation for the AVI Controller. When set to false the custom-vpc-name and custom-subnetwork-name must be set. | `bool` | `"true"` | no |
| <a name="input_custom_controller_name"></a> [custom\_controller\_name](#input\_custom\_controller\_name) | This field can be used to specify a custom controller name to replace the (prefix-avi-controller) standard name.  A numeric iterator will still be appended to the custom name (1,2,3) | `string` | `null` | no |
| <a name="input_custom_controller_subnet_ids"></a> [custom\_controller\_subnet\_ids](#input\_custom\_controller\_subnet\_ids) | This field can be used to specify a list of existing VPC Subnets for the Controllers.  The create-networking variable must also be set to false for this network to be used. | `list(string)` | `null` | no |
| <a name="input_custom_subnet_ids"></a> [custom\_subnet\_ids](#input\_custom\_subnet\_ids) | This field can be used to specify a list of existing VPC Subnets for the SEs. The create-networking variable must also be set to false for this network to be used. | `list(string)` | `null` | no |
| <a name="input_custom_tags"></a> [custom\_tags](#input\_custom\_tags) | Custom tags added to AWS Resources created by the module | `map(string)` | `{}` | no |
| <a name="input_custom_vpc_id"></a> [custom\_vpc\_id](#input\_custom\_vpc\_id) | This field can be used to specify an existing VPC for the SEs. The create-networking variable must also be set to false for this network to be used. | `string` | `null` | no |
| <a name="input_dns_search_domain"></a> [dns\_search\_domain](#input\_dns\_search\_domain) | The optional DNS search domain that will be used by the controller | `string` | `null` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | The optional DNS servers that will be used for local DNS resolution by the controller. Example ["8.8.4.4", "8.8.8.8"] | `list(string)` | `null` | no |
| <a name="input_email_config"></a> [email\_config](#input\_email\_config) | The Email settings that will be used for sending password reset information or for trigged alerts. The default setting will send emails directly from the Avi Controller | `object({ smtp_type = string, from_email = string, mail_server_name = string, mail_server_port = string, auth_username = string, auth_password = string })` | <pre>{<br>  "auth_password": "",<br>  "auth_username": "",<br>  "from_email": "admin@avicontroller.net",<br>  "mail_server_name": "localhost",<br>  "mail_server_port": "25",<br>  "smtp_type": "SMTP_LOCAL_HOST"<br>}</pre> | no |
| <a name="input_firewall_controller_allow_source_range"></a> [firewall\_controller\_allow\_source\_range](#input\_firewall\_controller\_allow\_source\_range) | The IP range allowed to connect to the Avi Controller. Access from all IP ranges will be allowed by default | `string` | `"0.0.0.0/0"` | no |
| <a name="input_firewall_controller_security_group_ids"></a> [firewall\_controller\_security\_group\_ids](#input\_firewall\_controller\_security\_group\_ids) | List of security group IDs that will be assigned to the controller. This variable must be set if the create\_firewall\_rules variable is set to false | `list(string)` | `null` | no |
| <a name="input_firewall_se_data_rules"></a> [firewall\_se\_data\_rules](#input\_firewall\_se\_data\_rules) | The data plane traffic allowed for Virtual Services hosted on Services Engines. The configure\_firewall\_rules variable must be set to true for these rules to be created | `list(object({ protocol = string, port = string, allow_ip_range = string, description = string }))` | <pre>[<br>  {<br>    "allow_ip_range": "0.0.0.0/0",<br>    "description": "https",<br>    "port": "443",<br>    "protocol": "tcp"<br>  },<br>  {<br>    "allow_ip_range": "10.0.0.0/8",<br>    "description": "DNS",<br>    "port": "53",<br>    "protocol": "udp"<br>  }<br>]</pre> | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The EC2 instance type for the Avi Controller | `string` | `"m5.2xlarge"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | The name of the existing EC2 Key pair that will be used to authenticate to the Avi Controller | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | This prefix is appended to the names of the Controller and SEs | `string` | n/a | yes |
| <a name="input_ntp_servers"></a> [ntp\_servers](#input\_ntp\_servers) | The NTP Servers that the Avi Controllers will use. The server should be a valid IP address (v4 or v6) or a DNS name. Valid options for type are V4, DNS, or V6 | `list(object({ addr = string, type = string }))` | <pre>[<br>  {<br>    "addr": "0.us.pool.ntp.org",<br>    "type": "DNS"<br>  },<br>  {<br>    "addr": "1.us.pool.ntp.org",<br>    "type": "DNS"<br>  },<br>  {<br>    "addr": "2.us.pool.ntp.org",<br>    "type": "DNS"<br>  },<br>  {<br>    "addr": "3.us.pool.ntp.org",<br>    "type": "DNS"<br>  }<br>]</pre> | no |
| <a name="input_private_key_contents"></a> [private\_key\_contents](#input\_private\_key\_contents) | The contents of the private key for the EC2 Key pair used for authenticating to the Avi Controller. Either private\_key\_path or private\_key\_contents must be supplied. | `string` | `null` | no |
| <a name="input_private_key_path"></a> [private\_key\_path](#input\_private\_key\_path) | The local private key path for the EC2 Key pair used for authenticating to the Avi Controller. Either private\_key\_path or private\_key\_contents must be supplied. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The Region that the AVI controller and SEs will be deployed to | `string` | n/a | yes |
| <a name="input_register_controller"></a> [register\_controller](#input\_register\_controller) | If enabled is set to true the controller will be registered and licensed with Avi Cloud Services. The Long Organization ID (organization\_id) can be found from https://console.cloud.vmware.com/csp/gateway/portal/#/organization/info. The jwt\_token can be retrieved at https://portal.avipulse.vmware.com/portal/controller/auth/cspctrllogin | `object({ enabled = bool, jwt_token = string, email = string, organization_id = string })` | <pre>{<br>  "email": "",<br>  "enabled": "false",<br>  "jwt_token": "",<br>  "organization_id": ""<br>}</pre> | no |
| <a name="input_se_ebs_encryption"></a> [se\_ebs\_encryption](#input\_se\_ebs\_encryption) | Enable encryption on SE AMI / EBS Volumes.  The AWS Managed EBS KMS key will be used if no key is provided with se\_ebs\_encryption\_key\_arn variable | `bool` | `"true"` | no |
| <a name="input_se_ebs_encryption_key_arn"></a> [se\_ebs\_encryption\_key\_arn](#input\_se\_ebs\_encryption\_key\_arn) | AWS Resource Name of an existing KMS key for SE AMI/EBS (se\_ebs\_encryption must be set to true) | `string` | `null` | no |
| <a name="input_se_ha_mode"></a> [se\_ha\_mode](#input\_se\_ha\_mode) | The HA mode of the default Service Engine Group. Possible values active/active, n+m, or active/standby | `string` | `"active/active"` | no |
| <a name="input_se_instance_type"></a> [se\_instance\_type](#input\_se\_instance\_type) | The instance type of the default Service Engine Group. Possible values can be found at https://aws.amazon.com/ec2/instance-types/ | `string` | `"c5.large"` | no |
| <a name="input_se_s3_encryption"></a> [se\_s3\_encryption](#input\_se\_s3\_encryption) | Enable encryption on SE S3 Bucket.  The AWS Managed S3 KMS key will be used if no key is provided with se\_s3\_encryption\_key\_arn variable | `bool` | `"true"` | no |
| <a name="input_se_s3_encryption_key_arn"></a> [se\_s3\_encryption\_key\_arn](#input\_se\_s3\_encryption\_key\_arn) | AWS Resource Name of an existing KMS key for SE S3 Bucket (se\_s3\_encryption must be set to true) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_controller_private_addresses"></a> [controller\_private\_addresses](#output\_controller\_private\_addresses) | The Private IP Addresses allocated for the Avi Controller(s) |
| <a name="output_controller_public_addresses"></a> [controller\_public\_addresses](#output\_controller\_public\_addresses) | Public IP Addresses for the AVI Controller(s) |
| <a name="output_controllers"></a> [controllers](#output\_controllers) | The AVI Controller(s) Information |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
