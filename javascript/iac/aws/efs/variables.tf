variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "deploy_name" {
}

variable "environment" {
}

variable "subnets" {
  type = list(string)
}

variable "efs_subnets_override" {
  default = ""
}

variable "vpc_id" {
}

variable "performance_mode" {
  description = "(Optional) The performance mode of your file system."
  type        = string
  default     = "maxIO"
}

variable "throughput_mode" {
  default = ""
}

variable "security_groups" {
  type = list(string)
}

variable "az_count" {
}

variable "provisioned_throughput_mb" {
}

variable "efs_cidrs" {
  default = []
}