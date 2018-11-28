resource "aws_security_group" "eks-worker" {
  name        = "${var.cluster-name}-worker"
  description = "Security group for all workers/nodes in the cluster"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.cluster-name}-worker",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

# Security group rules general and CAP-specific (please test)

resource "aws_security_group_rule" "eks-worker-ingress-workers" {
  description              = "Allow workers to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-worker.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-worker-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

# CAP specifics

resource "aws_security_group_rule" "eks-worker-ingress-cap-http" {
  description              = "Allow CloudFoundry to communicate on http port"
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 80
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-worker-ingress-cap-uaa" {
  description              = "Allow CloudFoundry to communicate for UAA"
  from_port                = 2793
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 2793
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-worker-ingress-cap-ssh" {
  description              = "Allow CloudFoundry to communicate for SSH"
  from_port                = 2222
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 2222
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-worker-ingress-cap-wss" {
  description              = "Allow CloudFoundry to communicate for WSS"
  from_port                = 4443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 4443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-worker-ingress-cap-brains" {
  description              = "Allow CloudFoundry to communicate for CAP Brains"
  from_port                = 20000
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 20009
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-worker-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-worker.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 443
  type                     = "ingress"
}

# Default AMI for EKS workers in eu-west-1 (Ireland)

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-v25"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}

data "aws_region" "current" {}
  
locals {
  eks-worker-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks-cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

# Could possibly use a bare ec2 resource here?

resource "aws_launch_configuration" "eks-worker" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.eks-worker.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "m4.large"
  name_prefix                 = "${var.cluster-name}"
  security_groups             = ["${aws_security_group.eks-worker.id}"]
  user_data_base64            = "${base64encode(local.eks-worker-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks-worker" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.eks-worker.id}"
  max_size             = 2
  min_size             = 1
  name                 = "${var.cluster-name}"
  vpc_zone_identifier  = ["${aws_subnet.main.*.id}"]

  tag {
    key                 = "Name"
    value               = "${var.cluster-name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

