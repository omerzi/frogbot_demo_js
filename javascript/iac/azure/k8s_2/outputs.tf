output "host" {
  value = try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].host,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].host)
}

output "client_certificate" {
  value = try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_certificate,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].client_certificate)
}

output "client_key" {
  value = try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_key,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].client_key)
}

output "cluster_ca_certificate" {
  value = try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].cluster_ca_certificate,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].cluster_ca_certificate)
}

output "k8s_cluster_name" {
  value = azurerm_kubernetes_cluster.k8s[0].name
}

output "k8s_cluster_id" {
  value = azurerm_kubernetes_cluster.k8s[0].id
}