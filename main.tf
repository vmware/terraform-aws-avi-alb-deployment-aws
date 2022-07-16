# Copyright 2021 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.22.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
  }
}
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}
