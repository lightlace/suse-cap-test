terraform {
  required_version = ">= 0.11.0"
}

locals {
  env    = "${var.cluster-name}"
  region = "eu-central-1"
}

provider "aws" {
  region  = "${local.region}"
  version = "~> 1.24"
}

data "aws_region" "current" {
  name = "${local.region}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source     = "./vpc"
  project    = "${local.env}"
  region     = "${local.region}"
}

module "cluster" {
  source     = "./cluster"
  project    = "${local.env}"
  region     = "${local.region}"
  vpc_id     = "${module.vpc.vpc_id}"
  subnets    = ["${module.vpc.subnets}"]
}

module "worker" {
  source     = "./worker"
  project    = "${local.env}"
  region     = "${local.region}"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_id  = "${module.vpc.subnet_id}"
}
