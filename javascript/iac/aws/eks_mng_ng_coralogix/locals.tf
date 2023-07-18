locals {
  common_labels = {
    "k8s.jfrog.com/jfrog_region"  = lower(var.narcissus_domain_short)
    "k8s.jfrog.com/project_name"  = lower(var.project_name)
    "k8s.jfrog.com/environment"   = lower(var.environment)
    "k8s.jfrog.com/cloud_region"  = lower(var.region)
    "k8s.jfrog.com/owner"         = "devops"
    "k8s.jfrog.com/purpose"       = "compute"
    "k8s.jfrog.com/workload_type" = "main"
    "k8s.jfrog.com/application"   = "all"
  }
  common_tags = merge({
    "jfrog_region"  = lower(var.narcissus_domain_short)
    "project_name"  = lower(var.project_name)
    "environment"   = lower(var.environment)
    "cloud_region"  = lower(var.region)
    "owner"         = "devops"
    "purpose"       = "compute"
    "workload_type" = "main"
    "application"   = "all"
  },var.eks_version_tag)
  node_pools_common_default_tags = {
    "be" : merge(local.common_tags, {}, try(var.eks_mng_map["be"]["tags"], {})),
    "osm" : merge(local.common_tags, {}, try(var.eks_mng_map["osm"]["tags"], {})),
    "osh" : merge(local.common_tags, {}, try(var.eks_mng_map["osh"]["tags"], {})),
    "osw" : merge(local.common_tags, {}, try(var.eks_mng_map["osw"]["tags"], {})),
    "osc" : merge(local.common_tags, {}, try(var.eks_mng_map["osc"]["tags"], {})),
    "osic" : merge(local.common_tags, {}, try(var.eks_mng_map["osic"]["tags"], {})),
    "kc" : merge(local.common_tags, {}, try(var.eks_mng_map["kc"]["tags"], {})),
    "zc" : merge(local.common_tags, {}, try(var.eks_mng_map["zc"]["tags"], {})),
    "cc" : merge(local.common_tags, {}, try(var.eks_mng_map["cc"]["tags"], {})),
    
  }

}