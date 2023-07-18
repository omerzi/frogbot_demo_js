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
    default = null
}

variable "vpc_id"{
  
}
variable "sg_map" {
  default ={}
}
variable "sdm_source_ranges" {
  
}
variable "ingress_cidr_blocks" {

}
variable "k8s_cidr_blocks"{
  default = []
}