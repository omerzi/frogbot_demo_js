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
  },var.wiz_tags,var.eks_version_tag)
  node_pools_common_default_labels = {
    "ft" : merge(local.common_labels, {
      "k8s.jfrog.com/subscription_type" = "free"
      "k8s.jfrog.com/customer"          = "shared-free-tier-customers"
      "k8s.jfrog.com/instance_type"     = try(var.eks_mng_map["ft"]["instance_type"], "")
    }, try(var.eks_mng_map["ft"]["labels"], {})),
    "ng" : merge(local.common_labels, {
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/customer"          = "shared-paying-customers"
      "k8s.jfrog.com/instance_type"     = try(var.eks_mng_map["ng"]["instance_type"], "")
    }, try(var.eks_mng_map["ng"]["labels"], {})),
    "xj" : merge(local.common_labels, {
      "k8s.jfrog.com/app_type"      = "xray-jobs"
      "k8s.jfrog.com/customer"      = "shared-xray-on-demand"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["xj"]["instance_type"], "")
    }, try(var.eks_mng_map["xj"]["labels"], {})),
    "env0" : merge(local.common_labels, {
      "k8s.jfrog.com/app_type"      = "env0"
      "k8s.jfrog.com/customer"      = "devops-infra"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["env0"]["instance_type"], "")
    }, try(var.eks_mng_map["env0"]["labels"], {})),
      "wix" : merge(local.common_labels, {
      "k8s.jfrog.com/customer"          = "dedicated-on-demand"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "wix"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["wix"]["instance_type"], "")
    }, try(var.eks_mng_map["wix"]["labels"], {})),
    "bitbucket" : merge(local.common_labels, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "bitbucket"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map.mpnodes.nodes["bitbucket"]["instance_type"], "")
      "k8s.jfrog.com/node_role" = "bitbucket"
    }, try(var.eks_mng_map.mpnodes.nodes["bitbucket"]["labels"], {})),
    "bitbucket-elk" : merge(local.common_labels, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "bitbucket-elk"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map.mpnodes.nodes["bitbucket-elk"]["instance_type"], "")
      "k8s.jfrog.com/node_role" = "elkbitbucket"
    }, try(var.eks_mng_map.mpnodes.nodes["bitbucket-elk"]["labels"], {})),
    "sonarqube" : merge(local.common_labels, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "sonarqube"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["sonarqube"]["instance_type"], "")
      "k8s.jfrog.com/node_role" = "sonar"
    }, try(var.eks_mng_map["sonarqube"]["labels"], {})),
    "jenkins" : merge(local.common_labels, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "jenkins"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["jenkins"]["instance_type"], "")
      "k8s.jfrog.com/node_role" = "jenkinsNode"
    }, try(var.eks_mng_map["jenkins"]["labels"], {})),
    "utp" : merge(local.common_labels, {
      "k8s.jfrog.com/customer" : "DevF"
      "k8s.jfrog.com/deployment_type": "release"
      "k8s.jfrog.com/subscription_type" : "utp"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["utp"]["instance_type"], "")
    }, try(var.eks_mng_map["utp"]["labels"], {})),
    "xuc" : merge(local.common_labels, {
      "k8s.jfrog.com/customer" : "xuc"
      "k8s.jfrog.com/dedicated_customer_nodepool" = "xuc"
      "k8s.jfrog.com/instance_type" = try(var.eks_mng_map["xuc"]["instance_type"], "")
    }, try(var.eks_mng_map["xuc"]["labels"], {})),
      "default-pl" : merge(local.common_labels, {
      "app_type"      = "pipelines"
      "customer"      = "shared-pipeline-on-demand"
      "instance_type" = try(var.eks_mng_map["pipelines"]["instance_type"], "")
    }, try(var.eks_mng_map["pipelines"]["labels"], {})),
      "rg" : merge(local.common_labels, {
      "k8s.jfrog.com/customer"          = "dedicated-on-demand"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "riotgames"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["rg"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["rg"]["labels"], {})),
      "devops" : merge(local.common_labels, {
      "app_type"      = "devops"
      "k8s.jfrog.com/pool_type" = "devops"
      "instance_type" = try(var.eks_mng_map["devops"]["instance_type"], "")
    }, try(var.eks_mng_map["devops"]["labels"], {})),
      "openebs" : merge(local.common_labels, {
      "app_type"      = "openebs"
      "owner"         = "dev-foundation"
      "k8s.jfrog.com/app_type" = "openebs"
      "instance_type" = try(var.eks_mng_map["openebs"]["instance_type"], "")
    }, try(var.eks_mng_map["devops"]["labels"], {})),
      "default" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "dev-foundation"
      "k8s.jfrog.com/pool_type"         = "default"
      "k8s.jfrog.com/customer"          = "jfrog-internal"
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/application"       = "default"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["default"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["default"]["labels"], {})),
      "artifactory" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "dev-foundation"
      "k8s.jfrog.com/pool_type"         = "artifactory"
      "k8s.jfrog.com/customer"          = "jfrog-internal"
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/application"       = "artifactory"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["artifactory"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["artifactory"]["labels"], {})),
      "xray" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"         = "dev-foundation"
      "k8s.jfrog.com/pool_type" = "xray"
      "k8s.jfrog.com/customer" = "jfrog-internal"
      "k8s.jfrog.com/subscription_type": "paying"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["xray"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["xray"]["labels"], {})),
      "distribution" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "dev-foundation"
      "k8s.jfrog.com/pool_type"         = "distribution"
      "k8s.jfrog.com/customer"          = "jfrog-internal"
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/application"       = "distribution"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["distribution"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["distribution"]["labels"], {})),
      "infra" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "dev-foundation"
      "k8s.jfrog.com/pool_type"         = "infra"
      "k8s.jfrog.com/customer"          = "jfrog-internal"
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/application"       = "infra"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["infra"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["infra"]["labels"], {})),
      "pipelines" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "dev-foundation"
      "k8s.jfrog.com/pool_type"         = "pipelines"
      "k8s.jfrog.com/customer"          = "jfrog-internal"
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/application"       = "pipelines"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["pipelines"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["pipelines"]["labels"], {})),
      "utp" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "dev-foundation"
      "k8s.jfrog.com/pool_type"         = "utp"
      "k8s.jfrog.com/customer"          = "jfrog-internal"
      "k8s.jfrog.com/subscription_type" = "paying"
      "k8s.jfrog.com/application"       = "utp"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["utp"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["utp"]["labels"], {})),
      "devops-pl" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "devops"
      "k8s.jfrog.com/pool_type"         = "devops"
      "k8s.jfrog.com/customer"          = "devops"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["devops-pl"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["devops-pl"]["labels"], {})),
       "prometheus" : merge(local.common_labels, {
      "k8s.jfrog.com/owner"             = "devops"
      "k8s.jfrog.com/pool_type"         = "prometheus"
      "k8s.jfrog.com/customer"          = "devops"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["prometheus"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["devops-pl"]["labels"], {})),
      "default-pl" : merge(local.common_labels, {
      "k8s.jfrog.com/pool_type"         = "pipelines"
      "k8s.jfrog.com/customer"           = "shared-pipeline-on-demand"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["default-pl"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["default-pl"]["labels"], {})),
      "salt" : merge(local.common_labels, {
      "dedicated"                         = "salt-hybrid"
      "k8s.jfrog.com/owner"               = "security"
      "k8s.jfrog.com/customer"            = "jfrog-internal"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["salt"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["salt"]["labels"], {})),
  }
  node_pools_common_default_tags = {
      "ft" : merge(local.common_tags, {
      "subscription_type" = "free"
      "customer"          = "shared-free-tier-customers"
      "instance_type"     = try(var.eks_mng_map["ft"]["instance_type"], "")
    }, try(var.eks_mng_map["ft"]["tags"], {})),
      "ng" : merge(local.common_tags, {
      "subscription_type" = "paying"
      "customer"          = "shared-paying-customers"
      "instance_type"     = try(var.eks_mng_map["ng"]["instance_type"], "")
    }, try(var.eks_mng_map["ng"]["tags"], {})),
      "xj" : merge(local.common_tags, {
      "app_type"      = "xray-jobs"
      "customer"      = "shared-xray-on-demand"
      "instance_type" = try(var.eks_mng_map["xj"]["instance_type"], "")
    }, try(var.eks_mng_map["xj"]["tags"], {})),
      "env0" : merge(local.common_tags, {
      "app_type"      = "env0"
      "k8s.jfrog.com/customer"          = "devops-infra"
      "instance_type" = try(var.eks_mng_map["env0"]["instance_type"], "")
    }, try(var.eks_mng_map["env0"]["tags"], {})),
      "wix" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "dedicated-on-demand"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "wix"
      "instance_type" = try(var.eks_mng_map["wix"]["instance_type"], "")
    }, try(var.eks_mng_map["wix"]["tags"], {})),
      "bitbucket" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "bitbucket"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["bitbucket"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["bitbucket"]["tags"], {})),
      "bitbucket-elk" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "bitbucket-elk"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["bitbucket-elk"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["bitbucket-elk"]["tags"], {})),
      "sonarqube" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "sonarqube"
      "instance_type" = try(var.eks_mng_map["sonarqube"]["instance_type"], "")
    }, try(var.eks_mng_map["sonarqube"]["tags"], {})),
      "jenkins" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "jenkins"
      "instance_type" = try(var.eks_mng_map["jenkins"]["instance_type"], "")
    }, try(var.eks_mng_map["jenkins"]["tags"], {})),
      "utp" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "DevF"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "utp"
      "k8s.jfrog.com/subscription_type" : "utp"
      "deployment_type" = "release"
      "instance_type" = try(var.eks_mng_map["utp"]["instance_type"], "")
    }, try(var.eks_mng_map["utp"]["tags"], {})),
      "pipelines" : merge(local.common_tags, {
      "app_type"      = "pipelines"
      "customer"      = "shared-pipeline-on-demand"
      "instance_type" = try(var.eks_mng_map["pipelines"]["instance_type"], "")
    }, try(var.eks_mng_map["pipelines"]["tags"], {})),
      "rg" : merge(local.common_tags, {
      "dedicated_customer_nodepool"         = "riotgames"
      "owner"             = "devops"
      "customer"          = "dedicated-on-demand"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["rg"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["rg"]["tags"], {})),
      "xuc" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "xuc"
      "k8s.jfrog.com/dedicated_customer_nodepool"= "xuc"
      "app_type" = "release"
      "instance_type" = try(var.eks_mng_map["xuc"]["instance_type"], "")
    }, try(var.eks_mng_map["xuc"]["tags"], {})),
      "devops" : merge(local.common_tags, {
      "k8s.jfrog.com/customer"          = "devops"
      "pool_type"                       = "devops"
      "instance_type" = try(var.eks_mng_map["devops"]["instance_type"], "")
    }, try(var.eks_mng_map["devops"]["tags"], {})),
      "openebs" : merge(local.common_tags, {
      "k8s.jfrog.com/app_type"          = "openebs"
      "pool_type"                       = "openebs"
      "owner"         = "dev-foundation"
      "instance_type" = try(var.eks_mng_map["openebs"]["instance_type"], "")
    }, try(var.eks_mng_map["openebs"]["tags"], {})),
      "default" : merge(local.common_tags, {
      "pool_type"         = "default"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "default"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["default"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["default"]["tags"], {})),
      "artifactory" : merge(local.common_tags, {
      "pool_type"         = "artifactory"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "artifactory"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["artifactory"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["artifactory"]["tags"], {})),
      "xray" : merge(local.common_tags, {
      "pool_type"         = "xray"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "xray"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["xray"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["xray"]["tags"], {})),
      "infra" : merge(local.common_tags, {
      "pool_type"         = "infra"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "infra"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["infra"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["infra"]["tags"], {})),
      "pipelines" : merge(local.common_tags, {
      "pool_type"         = "pipelines"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "pipelines"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["pipelines"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["pipelines"]["tags"], {})),
      "distribution" : merge(local.common_tags, {
      "pool_type"         = "distribution"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "distribution"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["distribution"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["distribution"]["tags"], {})),
      "utp" : merge(local.common_tags, {
      "pool_type"         = "utp"
      "owner"             = "dev-foundation"
      "subscription_type" = "paying"
      "customer"          = "dev-foundation"
      "application"       = "utp"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["utp"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["utp"]["tags"], {})),
      "salt" : merge(local.common_tags, {
      "dedicated"         = "salt-hybrid"
      "owner"             = "security"
      "customer"          = "security"
      "application"       = "salt"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["salt"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["salt"]["tags"], {})),
      "devops-pl" : merge(local.common_tags, {
      "pool_type"         = "devops"
      "owner"             = "devops"
      "customer"          = "devops"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["devops-pl"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["devops-pl"]["tags"], {})),
      "prometheus" : merge(local.common_tags, {
      "pool_type"         = "prometheus"
      "owner"             = "devops"
      "customer"          = "devops"
      "instance_type"     = try(var.eks_mng_map.mpnodes.nodes["prometheus"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["devops-pl"]["tags"], {})),
      "default-pl" : merge(local.common_tags, {
      "app_type"      = "pipelines"
      "customer"      = "shared-pipeline-on-demand"
      "instance_type" = try(var.eks_mng_map.mpnodes.nodes["default-pl"]["instance_type"], "")
    }, try(var.eks_mng_map.mpnodes.nodes["default-pl"]["tags"], {})),
    
  }

ft_user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/freetier.sh") : filebase64("${path.module}/freetier-v2.sh")
ng_user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true  ? filebase64("${path.module}/node.sh") : filebase64("${path.module}/node-v2.sh")
xray_user_data = contains(keys(var.eks_mng_map.override),"enable_v2_script") != true ? filebase64("${path.module}/xray-jobs.sh") : filebase64("${path.module}/xray-jobs-v2.sh")

}