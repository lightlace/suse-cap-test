resource "aws_security_group" "eks-worker" {
  name        = "${var.cluster-name}-worker"
  description = "Security group for all workers in the cluster"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
     Name = "${var.cluster-name}"
  }
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
    key                 = "${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

data "aws_region" "current" {}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml
locals {
  eks-worker-userdata = <<USERDATA
#!/bin/bash -xe

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
echo "${aws_eks_cluster.eks-cluster.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks-cluster.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${var.cluster-name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${data.aws_region.current.name},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks-cluster.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
USERDATA
}
