output "worker_security_group_id" {
  description = "Security group ID attached to the EKS workers."
  value       = module.eks.worker_security_group_id
}

//output "kubeconfig" {
//  description = "Security group ID attached to the EKS workers."
//  value       = "${module.eks.kubeconfig}"
//}
//output "kubeconfig_filename" {
//  description = "Security group ID attached to the EKS workers."
//  value       = "${module.eks.kubeconfig_filename}"
//}
//output "kubeconfig_token" {
//  value       = "${data.aws_eks_cluster_auth.k8s.token}"
//}
