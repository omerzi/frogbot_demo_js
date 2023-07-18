output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
#  value = var.region == "us-west-1" ? slice(module.vpc.private_subnets, 1, length(module.vpc.private_subnets)) : module.vpc.private_subnets
}
output "private_subnet_secondary_subnets"{
  value = module.vpc.private_subnet_secondary_subnets
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "database_subnets" {
  value = module.vpc.database_subnets
#  value = var.region == "us-west-1" ? slice(module.vpc.database_subnets, 1, length(module.vpc.database_subnets)) : module.vpc.database_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "intra_subnets" {
  value = module.vpc.intra_subnets
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "vpc_owner_id" {
  value = module.vpc.vpc_owner_id
}

output "private_route_table_ids"{
value       = module.vpc.private_route_table_ids
}

output "private_subnet_secondary_cidr_route_table_ids"{
value       = module.vpc.private_subnet_secondary_cidr_route_table_ids
}