output "eks_cluster_endpoint" {
  value = aws_eks_cluster.aws_eks.*.endpoint
}

output "eks_cluster_certificat_authority" {
  value = data.aws_eks_cluster.cluster[0].certificate_authority.0.data
}

output "eks_cluster_security_group_id" {
  value = try(data.aws_eks_cluster.cluster.*.vpc_config[0][0].cluster_security_group_id, "")
}
