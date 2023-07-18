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
variable "secondary_subnets"{
  default = []
}
variable "rbac_admin_namespaces"{
  default = {}
}
variable "environment" {
}
variable "rbac_pod_exec_roles" {
  default = []
}
variable "cluster_version" {
}

variable "aws_account_id" {
}
variable "jfapps_ba_ns" {
  default = [] 
}

variable "eks_mng_map" {
}
variable "create_ebs_csi_driver" { 
}
variable "private_link_tg" {
  default = ""
}

variable "private_link_tg_plain" {
  default = ""
}

variable "aws_arn" {}

variable "http_endpoint" {
}
variable "create_oidc"{
}
variable "wiz_tags" {
default = {}
}

variable "eks_version_tag" {
  default = {}
}
variable "region" {
}
variable "launch_template_tags" {
  default = {}
}
variable "narcissus_domain_short" {
  type = string
}

variable "project_name" {
  type = string
}

variable "enable_tags" {
  default = false
}
variable "rbac_admin_roles"{
default = []
}

variable "rbac_readonly_roles"{
default = []
}

variable "enable_ebs_csi" {
  }

variable "file_system_id" {
  }

variable "anitian_sshkey" {
  default = ""
}
variable "kms_key_arn"{
  default = null
}

variable "anitian_s3" {
  default = ""
}

variable "pileus_enabled" {
  default = false
}

variable "coralogix_user" {}