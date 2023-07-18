locals {
  common_labels = {
    "k8s.jfrog.com/jfrog_region"  = lower(var.narcissus_domain_short)
    "k8s.jfrog.com/project_name"  = lower(var.cloud_subscription)
    "k8s.jfrog.com/environment"   = lower(var.environment)
    "k8s.jfrog.com/cloud_region"  = lower(var.region)
    "k8s.jfrog.com/owner"         = "devops"
    "k8s.jfrog.com/purpose"       = "compute"
    "k8s.jfrog.com/workload_type" = "main"
    "k8s.jfrog.com/application"   = "all"
  }
  common_tags = {
    "jfrog_region"  = lower(var.narcissus_domain_short)
    "project_name"  = lower(var.cloud_subscription)
    "environment"   = lower(var.environment)
    "cloud_region"  = lower(var.region)
    "owner"         = "devops"
    "purpose"       = "compute"
    "workload_type" = "main"
    "application"   = "all"
    "WizExclude"    = ""
  }
  node_pools_common_default_labels = {
    "ft" : merge(local.common_labels, {
      "k8s.jfrog.com/subscription_type" = "free"
      "k8s.jfrog.com/customer"          = "shared-free-tier-customers"
      "k8s.jfrog.com/instance_type"     = try(var.aks_map["ft"]["instance_type"], "")
    }, try(var.aks_map["ft"]["labels"], {})),
    "ng" : merge(local.common_labels, {
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/customer"          = "shared-paying-customers"
      "k8s.jfrog.com/instance_type"     = try(var.aks_map["ng"]["instance_type"], "")
    }, try(var.aks_map["ng"]["labels"], {})),
    "xj" : merge(local.common_labels, {
      "k8s.jfrog.com/app_type"      = "xray-jobs"
      "k8s.jfrog.com/customer"      = "shared-xray-on-demand"
      "k8s.jfrog.com/instance_type" = try(var.aks_map["xj"]["instance_type"], "")
    }, try(var.aks_map["xj"]["labels"], {})),
      "devops" : merge(local.common_tags, {
      "instance_type" = try(var.aks_map["devops"]["instance_type"], "")
      "k8s.jfrog.com/pool_type"      = "devops"
      "k8s.jfrog.com/customer"      = "devops"     
    }, try(var.aks_map["devops"]["labels"], {})),
  }
  node_pools_common_default_tags = {
    "ft" : merge(local.common_tags, {
      "subscription_type" = "free"
      "customer"          = "shared-free-tier-customers"
      "instance_type"     = try(var.aks_map["ft"]["instance_type"], "")
    }, try(var.aks_map["ft"]["tags"], {})),
    "ng" : merge(local.common_tags, {
      "subscription_type" = "paying"
      "customer"          = "shared-paying-customers"
      "instance_type"     = try(var.aks_map["ng"]["instance_type"], "")
    }, try(var.aks_map["ng"]["tags"], {})),
    "xj" : merge(local.common_tags, {
      "app_type"      = "xray-jobs"
      "customer"      = "shared-xray-on-demand"
      "instance_type" = try(var.aks_map["xj"]["instance_type"], "")
    }, try(var.aks_map["xj"]["tags"], {})),
      "devops" : merge(local.common_tags, {
      "instance_type" = try(var.aks_map["devops"]["instance_type"], "")
      "customer"      = "devops"
    }, try(var.aks_map["devops"]["tags"], {})),
  }
}