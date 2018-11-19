resource "aws_iam_role" "eks-cap" {
  name = "${var.project}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cap-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-cap.name}"
}

resource "aws_iam_role_policy_attachment" "eks-cap-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-cap.name}"
}

resource "aws_security_group" "main" {
  name        = "${var.project}-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project}-cluster"
  }
}

resource "aws_eks_cluster" "suse-cap" {
  name            = "${var.project}"
  role_arn        = "${aws_iam_role.eks-cap.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.main.id}"]
    subnet_ids         = ["${var.subnets}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-cap-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-cap-cluster-AmazonEKSServicePolicy",
  ]
}
