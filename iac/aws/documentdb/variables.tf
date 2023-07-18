variable "module_enabled" {
  default = true
}

variable "deploy_name" {
}

variable "enabled_cloudwatch_logs_exports" {
  type    = list(string)
  default = []
}

variable "engine" {
  default = "docdb"
}

variable "engine_version" {
}

variable "master_username" {
  default = "master"
}

variable "port" {
  default = 27017
}

variable "node_type" {
}

variable "num_nodes" {
}

variable "skip_final_snapshot" {
  default = true
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

