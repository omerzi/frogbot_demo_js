variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "deploy_name" {
}

variable "environment" {
}
variable "secondary_cidr_blocks"{
  default =[]
}
variable "secondary_subnets"{
  default = []
}
variable "vpc_map" {
}
variable "create_secondary_cidr_route_table"{
  default= false
}
variable "private_seconadry_cidr_route_table_ids"{
  default = []
}
variable "public_subnets_sub_region" {
  default = {}
}
variable "private_secondary_route_table_ids"{
  default = ""
}

variable "is_sub_region" {
  default = false
}

variable "vpc_self_link" {
  default = ""
}

variable "private_route_table_ids" {
  default = ""
}
variable "core_network_arn"{
default = null
}

variable "connect_to_global_network" {
  default = false
}
variable "core_network_id" {
  default = null
}

variable "database_subnet_tags" {
  description = "Additional tags for the database subnets"
  type        = map(string)
  default     = {}
}