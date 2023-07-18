variable "module_enabled" {
  default = true
}

variable "deploy_name" {
}

variable "vpc_id" {
}

variable "subnets" {
  type = list(string)
}

variable "environment" {
}

variable "msk_nodes" {
}

variable "instance_type" {
}

variable "kafka_version" {
}

variable "ebs_volume_size" {
}

variable "ingress_cidr_blocks" {
}

