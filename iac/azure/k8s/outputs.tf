output "host" {
  value = azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].host
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_certificate
}

output "client_key" {
  value = azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_key
}

output "cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].cluster_ca_certificate
}

output "management-lb-ip" {
  value = element(
    concat(
      kubernetes_service.management-lb.*.load_balancer_ingress.0.ip,
      [""],
    ),
    0,
  )
}

output "k8s_cluster_name" {
  value = azurerm_kubernetes_cluster.k8s[0].name
}

