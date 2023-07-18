variable "module_enabled" {
  default = false
}

variable "region" {
}

variable "deploy_name" {
}

//variable "organization" {
//}
//
//variable "acl" {
//}


variable "environment" {
    type = string
}

//variable "bucket_name" {
//
//}

variable "block_public_acls" {
  default = true
}
variable "ignore_public_acls" {
  default = true
}
variable "block_public_policy" {
  default = true
}
variable "restrict_public_buckets" {
  default = true
}
variable "s3_buckets" {
  type        = any
  default     = {}
}

variable "s3_tags"{
  type = map(string)
  default = {}
}

//variable "narcissus_domain_short" {
//  type = string
//}
//
//variable "narcissus_domain_name" {
//  type = string
//}
//
//
//variable "project_name" {
//  type = string
//}