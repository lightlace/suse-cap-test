resource "aws_security_group" "eks-cluster" {
  name        = "${var.cluster-name}-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.cluster-name}"
  }
}

# The actual EKS resource

resource "aws_eks_cluster" "eks-cluster" {
  name            = "${var.cluster-name}-cluster"
  role_arn        = "${aws_iam_role.eks-cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks-cluster.id}"]
    subnet_ids         = ["${aws_subnet.main.*.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy",
  ]
}
