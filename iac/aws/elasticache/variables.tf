variable "module_enabled" {
  default = true
}

variable "subnets" {
  type = list(string)
}

variable "deploy_name" {
}

variable "engine" {
  default = "redis"
}

variable "engine_version" {
}

variable "node_type" {
}

variable "num_node_groups" {
}

variable "replicas_per_node_group" {
  default = 1
}

variable "port" {
  default = 6379
}

variable "apply_immediately" {
  default = true
}

variable "vpc_id" {
}

variable "ingress_cidr_blocks" {
}

variable "ingress_rules" {
}

