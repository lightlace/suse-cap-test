terraform {
  required_version = ">= 0.11.0"
}

provider "aws" {
  region     = "eu-west-1",
  version = "~> 1.24"
}

data "aws_availability_zones" "available" {}
