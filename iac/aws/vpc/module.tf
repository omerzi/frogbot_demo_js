resource "aws_eip" "nat" {
  count = var.module_enabled && lookup(var.vpc_map,"enable_nat_gateway",true) ? length(lookup(var.vpc_map, "aws_azs")) : "0"
  vpc   = true
}

#data "aws_availability_zones" "available" {}

module "vpc" {
  create_vpc = var.module_enabled
  source     = "./module2"
  name       = "${var.deploy_name}-${var.region}"
  cidr       = lookup(var.vpc_map, "cidr")
  environment = var.environment
  core_network_arn = var.core_network_arn
  connect_to_global_network = var.connect_to_global_network
  core_network_id           = var.core_network_id
  create_secondary_cidr_route_table = var.create_secondary_cidr_route_table
  private_secondary_route_table_ids = var.private_secondary_route_table_ids
  azs              = lookup(var.vpc_map, "aws_azs")
  public_subnets   = lookup(var.vpc_map, "public_subnets", [])
  private_subnet_secondary_cidr = lookup(var.vpc_map, "private_subnet_secondary_cidr",[])
  private_subnets  = lookup(var.vpc_map, "private_subnets", [])
  database_subnets = lookup(var.vpc_map, "database_subnets", [])
  intra_subnets    = lookup(var.vpc_map, "intra_subnets", [])
  database_secondary_subnets   = lookup(var.vpc_map,"database_secondary_subnets",[])
  db_subnetgroup_override = lookup(var.vpc_map,"db_subnetgroup_override",[])
  elasticache_subnets    = contains(keys(var.vpc_map), "elasticache_subnets")  ? lookup(var.vpc_map, "elasticache_subnets") : toset([])
  is_sub_region          = var.is_sub_region
  vpc_self_link          = var.vpc_self_link
  private_route_table_ids = var.private_route_table_ids
  enable_nat_gateway   = lookup(var.vpc_map,"enable_nat_gateway",true)
  single_nat_gateway   = false
  reuse_nat_ips        = true
  external_nat_ip_ids  = aws_eip.nat.*.id
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  secondary_cidr_blocks = var.secondary_cidr_blocks
  vpc_tags = try(var.vpc_map.tags["vpc"], {
    "kubernetes.io/cluster/${var.deploy_name}-${var.region}" = "shared"
    "kubernetes.io/cluster/${var.deploy_name}"               = "shared"
  })
  private_subnet_tags = merge(try(var.vpc_map.tags["private_subnet"], {}), {
    "kubernetes.io/cluster/${var.deploy_name}-${var.region}" = "shared"
    "kubernetes.io/cluster/${var.deploy_name}"               = "shared"
  })  

  private_secondary_cidr_subnet_tags =contains(keys(var.vpc_map), "enable_tags_for_internal_lb") ?  merge(try(var.vpc_map.tags["private_subnet_secondary_cidr"], {}), {
    "kubernetes.io/cluster/${var.deploy_name}-${var.region}" = "shared"
    "kubernetes.io/role/internal-elb"                   : "1"
  }) : null
  
  elasticache_subnet_tags = try(var.vpc_map.tags["elasticache_subnets"], {
    "kubernetes.io/cluster/${var.deploy_name}-${var.region}" = "shared"
    "kubernetes.io/cluster/${var.deploy_name}"               = "shared"
  })

  public_subnet_tags = merge(var.public_subnets_sub_region,try(var.vpc_map.tags["public_subnet"], {
    "kubernetes.io/cluster/${var.deploy_name}-${var.region}" = "owned"
    "kubernetes.io/cluster/${var.deploy_name}-2-${var.region}" = "owned"
    "kubernetes.io/cluster/${var.deploy_name}-3-${var.region}" = "owned"
    "kubernetes.io/cluster/${var.deploy_name}"               = "owned"
    "kubernetes.io/role/elb"                                 = "1"
  }))

  tags = {
    Terraform         = "true"
    Environment       = var.environment
    KubernetesCluster = "${var.deploy_name}-${var.region}"
  }
  database_subnet_tags = var.database_subnet_tags
}
