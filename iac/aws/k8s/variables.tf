variable "module_enabled" {
  default = true
}

variable "region" {
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

variable "asg_desired_capacity" {
}

variable "asg_min_size" {
}

variable "asg_max_size" {
}

variable "instance_type" {
}

variable "key_name" {
}

variable "cluster_version" {
}

variable "aws_account_id" {
  type = map(string)
  default = {
    production         = "152153062141"
    staging            = "762952282510"
    staging-gov        = "155998361711"
  }
}

variable "root_volume_size" {
}

variable "worker_group_count" {
}

