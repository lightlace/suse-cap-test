output "eks_endpoint" {
  value = "${aws_eks_cluster.suse-cap.endpoint}"
}
