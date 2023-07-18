resource "azurerm_kubernetes_cluster" "k8s" {
  count                           = var.module_enabled ? 1 : 0
  name                            = lookup(var.aks_map.override, "cluster_name", "${var.deploy_name}-${var.region}")
  kubernetes_version              = lookup(var.aks_map.override, "aks_version", "1.18.14")
  sku_tier                        = lookup(var.aks_map.override, "sku_tier")
  http_application_routing_enabled= lookup(var.aks_map.override,"http_application_routing_enabled",false)
  location                        = var.region
  resource_group_name             = var.resource_group_name
  dns_prefix                      = lookup(var.aks_map.override, "cluster_dns_prefix" ,var.aks_map.override["cluster_name"])
  api_server_authorized_ip_ranges = concat(lookup(var.aks_map.override, "api_server_authorized_ip_ranges"), var.ssh_proxy_ip)
  tags = {
    environment = var.environment
  }

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = var.ssh_key
    }

  }


    dynamic oms_agent {
   for_each = contains(keys(var.aks_map.override), "log_analytics_workspace_id") == true ? ["exec"] : []
      content {
      log_analytics_workspace_id     = lookup(var.aks_map.override, "log_analytics_workspace_id")

      }
   }

  # identity {
  #   type = "SystemAssigned"
  # }
dynamic "service_principal" {
    for_each = contains(keys(var.aks_map.override), "enable_managed_identity") != true ? ["identity"] : []
    content{
    client_id     = azuread_application.client[0].application_id
    client_secret = azuread_service_principal_password.client[0].value   
    } 
}
 dynamic "identity" {
    for_each = contains(keys(var.aks_map.override), "enable_managed_identity") ? ["identity"] : []
    content {
      type                      = "SystemAssigned"
    }
  }

  ##### default node group (ng) paying customers #####
  default_node_pool {
    name                = lookup(var.aks_map.ng, "name", "default01" )
    node_count          = lookup(var.aks_map.ng, "desired_size", 1) // Leaving this for K8S service to manage per load once already inisitalized , see Lifecycle
    vm_size             = lookup(var.aks_map.ng, "instance_type")
    os_disk_size_gb     = lookup(var.aks_map.ng, "disk_size", 2000)
    vnet_subnet_id      = var.subnet
    type                = "VirtualMachineScaleSets"
    max_pods            = "110"
    enable_auto_scaling = false
    node_labels = var.enable_tags ? local.node_pools_common_default_labels.ng : tomap({
      "k8s.jfrog.com/subscription_type" = "paying"
    })
    min_count           = lookup(var.aks_map.ng, "min_size", 1)
    max_count           = lookup(var.aks_map.ng, "max_size", 100)
    tags = merge({
      environment                = var.environment
      cluster-autoscaler-enabled = "true"
      cluster-autoscaler-name    = lookup(var.aks_map.override, "cluster_dns_prefix" ,var.aks_map.override["cluster_name"])
      min                        = 3
      max                        = 100
    }, var.enable_tags ? local.node_pools_common_default_tags.ng : {})
  }


  network_profile {
    network_plugin     = "kubenet"
    network_policy     = "calico"
//    load_balancer_sku  = var.lb_sku // Optional Defaults to Standard
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
  }
  role_based_access_control_enabled = contains(keys(var.aks_map.override), "disable_aad_rbac") != true
    dynamic "azure_active_directory_role_based_access_control" {
      for_each = contains(keys(var.aks_map.override), "disable_aad_rbac") != true ? ["identity"] : []
      content {
      server_app_id     = azuread_application.server[0].application_id
      server_app_secret = azuread_service_principal_password.server[0].value
      client_app_id     = azuread_application.client[0].application_id
      tenant_id         = var.tenant_id
      }
    }

  depends_on = [
    azuread_service_principal_password.client,
    azuread_service_principal_password.server,
  ]

  lifecycle {
    ignore_changes = [
      automatic_channel_upgrade,
      default_node_pool.0.node_count,
      azure_active_directory_role_based_access_control, # Ignore till Managed-Identity implementation
      service_principal                                   # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ]
  }
}

##### freetier (ft) node group #####
resource "azurerm_kubernetes_cluster_node_pool" "freetier" {
  name                = lookup(var.aks_map.ft, "name", "freetier01" )
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s[0].id
  vm_size               = lookup(var.aks_map.ft, "instance_type")
  enable_auto_scaling   = false
  min_count             = lookup(var.aks_map.ft, "min_size", 1)
  max_count             = lookup(var.aks_map.ft, "max_size", 100)
  os_disk_size_gb       = lookup(var.aks_map.ng, "disk_size", 1000)
  node_taints           = ["subscription_type=free:NoSchedule"]
  workload_runtime      = lookup(var.aks_map.ft, "workload_runtime", null)
  node_labels = var.enable_tags ? local.node_pools_common_default_labels.ft : tomap({
    "k8s.jfrog.com/subscription_type" = "free"
  })
  vnet_subnet_id        = var.subnet
  tags = merge({
  #  environment                = var.environment
    cluster-autoscaler-enabled = "true"
    cluster-autoscaler-name    = lookup(var.aks_map.override, "cluster_dns_prefix" ,var.aks_map.override["cluster_name"])
    min                        = 1
    max                        = 100
  }, var.enable_tags ? local.node_pools_common_default_tags.ft : {})

  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
    lifecycle {
    ignore_changes = [
    ]
  }

}

##### xray-jobs (xj) node group #####
resource "azurerm_kubernetes_cluster_node_pool" "xray-jobs" {
  count                 = contains(keys(var.aks_map), "xj")  ? 1 : 0
  name                  = lookup(var.aks_map.xj, "name", "xrayjobs01" )
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s[0].id
  vm_size               = lookup(var.aks_map.xj, "instance_type")
  enable_auto_scaling   = false
  min_count             = lookup(var.aks_map.xj, "min_size", 1)
  max_count             = lookup(var.aks_map.xj, "max_size", 100)
  os_disk_size_gb       = lookup(var.aks_map.xj, "disk_size", 1000)
  node_taints           = ["app_type=xray-jobs:NoSchedule"]
  node_labels = var.enable_tags ? local.node_pools_common_default_labels.xj : tomap({
    "k8s.jfrog.com/app_type" = "xray-jobs"
  })
  vnet_subnet_id        = var.subnet
  tags = merge({
  #  environment                = var.environment
    cluster-autoscaler-enabled = "true"
    cluster-autoscaler-name    = lookup(var.aks_map.override, "cluster_name", "${var.deploy_name}-${var.region}")
    min                        = 1
    max                        = 100
  }, var.enable_tags ? local.node_pools_common_default_tags.xj : {})

  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
  lifecycle {
    ignore_changes = [

    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "devops" {
  count                 = contains(keys(var.aks_map), "devops")  ? 1 : 0
  name                  = lookup(var.aks_map.devops, "name", "do01" )
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s[0].id
  vm_size               = lookup(var.aks_map.devops, "instance_type")
  enable_auto_scaling   = false
  min_count             = lookup(var.aks_map.devops, "min_size", 1)
  max_count             = lookup(var.aks_map.devops, "max_size", 100)
  os_disk_size_gb       = lookup(var.aks_map.devops, "disk_size", 1000)
  node_taints           = ["pool_type=devops:NoSchedule"]
  node_labels = var.enable_tags ? local.node_pools_common_default_labels.devops : tomap({
    "k8s.jfrog.com/pool_type" = "devops"
  })
  zones                 = try(lookup(var.aks_map.devops, "multi_zone",false) == true ?  var.zones : null,null)
  vnet_subnet_id        = var.subnet
  node_count = 3
  tags = merge({
  #  environment                = var.environment
    cluster-autoscaler-enabled = "true"
    cluster-autoscaler-name    = lookup(var.aks_map.override, "cluster_name", "${var.deploy_name}-${var.region}")
    min                        = 3
    max                        = 100
  }, var.enable_tags ? local.node_pools_common_default_tags.devops : {})

  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
  lifecycle {
    ignore_changes = [
     node_count
    ]
  }
}


provider "kubernetes" {
  load_config_file       = false
  host                   = try(var.aks_map.override["k8s_sdm"], try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].host, azurerm_kubernetes_cluster.k8s[0].kube_config[0].host))
  client_certificate     = base64decode(
  try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_certificate,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].client_certificate)
  )
  client_key             = base64decode(
  try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_key,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].client_key)
  )
  cluster_ca_certificate = base64decode(
  try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].cluster_ca_certificate,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].cluster_ca_certificate)
  )
}

# k8s nat gw with public ip association resources
resource "azurerm_nat_gateway" "k8s_nat_gw" {
  count                   = var.nat_gw_module_enabled != 0 ? 1 : 0
  name                    = "${var.resource_group_name}-nat-gw"
  location                = var.region
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = {
    environment = var.environment
  }
  depends_on = [
    azurerm_kubernetes_cluster.k8s,
    azurerm_kubernetes_cluster_node_pool.freetier
  ]
}
resource "azurerm_nat_gateway_public_ip_association" "k8s_nat_gw_pub_ip_association" {
  count                = var.k8s_nat_public_ips_count
  nat_gateway_id       = azurerm_nat_gateway.k8s_nat_gw[0].id
  public_ip_address_id = var.k8s_public_ip_ids[count.index]

  depends_on = [
    azurerm_nat_gateway.k8s_nat_gw
  ]
}
resource "azurerm_subnet_nat_gateway_association" "k8s_nat_gw_subnet_association" {
  count           = var.nat_gw_module_enabled != 0 ? 1 : 0
  nat_gateway_id  = azurerm_nat_gateway.k8s_nat_gw[count.index].id
  subnet_id       = var.subnet

  depends_on = [
    azurerm_nat_gateway_public_ip_association.k8s_nat_gw_pub_ip_association
  ]
}
