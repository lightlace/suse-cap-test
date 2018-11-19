locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${module.cluster.aws_eks_cluster.suse-cap.endpoint}
    certificate-authority-data: ${module.cluster.aws_eks_cluster.suse-cap.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG


config-map-aws-auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
name: aws-auth
namespace: kube-system
data:
mapRoles: |
- rolearn: ${module.cluster.aws_iam_role.eks-cap.arn}
username: system:node:{{EC2PrivateDNSName}}
groups:
- system:bootstrappers
- system:nodes
CONFIGMAPAWSAUTH
}

output "config-map-aws-auth" {
  value = "${local.config-map-aws-auth}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}
