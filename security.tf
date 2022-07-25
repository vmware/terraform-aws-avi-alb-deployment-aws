# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_security_group" "avi_controller_sg" {
  count       = var.create_firewall_rules ? 1 : 0
  name        = "${var.name_prefix}-avi-controller-sg"
  description = "Allow Traffic for AVI Controller"
  vpc_id      = var.create_networking ? aws_vpc.avi[0].id : var.custom_vpc_id

  ingress {
    description = "SSH Ingress"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.firewall_controller_allow_source_range]
  }
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.firewall_controller_allow_source_range]
  }
  ingress {
    description = "Secure Channel from VPC"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.avi_cidr_block]
  }
  ingress {
    description = "AVI_CLI from Internet"
    from_port   = 5054
    to_port     = 5054
    protocol    = "tcp"
    cidr_blocks = [var.firewall_controller_allow_source_range]
  }
  ingress {
    description = "ICMP to Controller"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.avi_cidr_block]
  }
  egress {
    description = "Allow traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-avi-controller-sg"
  }
}
resource "aws_security_group" "avi_se_mgmt_sg" {
  count       = var.create_firewall_rules ? 1 : 0
  name        = "${var.name_prefix}-avi-se-mgmt-sg"
  description = "Allow traffic for AVI SE MGMT NICs"
  vpc_id      = var.create_networking ? aws_vpc.avi[0].id : var.custom_vpc_id

  ingress {
    description = "SSH to SE"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.avi_cidr_block]
  }
  ingress {
    description = "Allow SE distributed object store traffic"
    from_port   = 4001
    to_port     = 4001
    protocol    = "tcp"
    cidr_blocks = [var.avi_cidr_block]
  }
  ingress {
    description = "ICMP to SE"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.avi_cidr_block]
  }
  ingress {
    description = "ETHERIP to SE"
    from_port   = -1
    to_port     = -1
    protocol    = "97"
    cidr_blocks = [var.avi_cidr_block]
  }
  ingress {
    description = "CPHB to SE"
    from_port   = -1
    to_port     = -1
    protocol    = "73"
    cidr_blocks = [var.avi_cidr_block]
  }
  ingress {
    description = "Proto63 to SE"
    from_port   = -1
    to_port     = -1
    protocol    = "63"
    cidr_blocks = [var.avi_cidr_block]
  }
  egress {
    description = "Allow SSH to Controller"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.avi_cidr_block]
  }
  egress {
    description = "Allow SE distributed object store traffic"
    from_port   = 4001
    to_port     = 4001
    protocol    = "tcp"
    cidr_blocks = [var.avi_cidr_block]
  }
  egress {
    description = "Allow 8443 to Controller"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.avi_cidr_block]
  }
  egress {
    description = "Allow NTP to Controller"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = [var.avi_cidr_block]
  }
  tags = {
    Name = "${var.name_prefix}-avi-se-mgmt-sg"
  }
}
resource "aws_security_group" "avi_data_sg" {
  count       = var.create_firewall_rules ? 1 : 0
  name        = "${var.name_prefix}-avi-data-sg"
  description = "Allow traffic for Avi SE Data NICs"
  vpc_id      = var.create_networking ? aws_vpc.avi[0].id : var.custom_vpc_id

  dynamic "ingress" {
    for_each = var.firewall_se_data_rules
    content {
      description = ingress.value["description"]
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["protocol"]
      cidr_blocks = [ingress.value["allow_ip_range"]]
    }
  }
  egress {
    description = "Allow Traffic Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name_prefix}-avi-data-sg"
  }
}
