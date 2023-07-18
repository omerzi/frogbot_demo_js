variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "deploy_name" {
}

variable "service_name" {
}

variable "disk_size_gb" {
}

variable "machine_type" {
}
variable "create_builders_sg"{
  default = false
}
variable "instance_count" {
}

variable "subnets" {
  type = list(string)
}

variable "vpc_id" {
}

variable "public_ip" {
}

variable "key_name" {
}
variable "vpc_security_group_override" {
  default = []
}

variable "asg_specified_ami" {
}

variable "port" {
}

variable "ingress_cidr_blocks" {
}

variable "sdm_source_ranges" {
}

variable "environment" {
}

variable "sshkeys" {
}

variable "ami" {}

variable "image_owner" {}

variable "detailed_monitoring" {
  default = false
}

variable "ebs_optimized" {
  default = false
}

variable "anitian_sg" {}

variable "ec2_instance_profile_name" {}

variable "anitian_s3" {
  default  = ""  
}

variable "anitian_sshkey" {
  default = ""
}
variable "create_security_groups"{
  default = true
}
variable "sdm_security_group_id"{
  default = null
}
variable "sdm_gateway" {
  default = false
}

variable "user_data_replace_on_change" {}