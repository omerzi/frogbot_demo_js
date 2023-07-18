variable "module_enabled" {
}

variable "subnets" {
}

variable "region" {
}

variable "environment" {
}

variable "vpc_id" {
}

variable "privatelink_map" {
}

variable "pl_domain" {
}

variable "zone_id" {
  default = ""
}

variable "isMainCluster" {
  default = true
}

variable "enable_private_dns" {
  default = false
}

variable "vpc_extra_pl_subnets" {
  default = [
    "192.168.14.0/27",
    "192.168.14.32/27",
    "192.168.14.64/27",
    "192.168.14.96/27",
    "192.168.14.128/27",
    "192.168.14.160/27"
  ]
}

variable "vpc_extra_pl_azs" {
  default = {
    us-east-1      = ["us-east-1b","us-east-1e","us-east-1f"]
    us-west-1      = []
    us-west-2      = ["us-west-2d"]
    eu-west-1      = []
    eu-central-1   = []
    ap-south-1     = []
    ap-southeast-1 = []
    ap-southeast-2 = []
    ap-northeast-1 = []
    ap-northeast-3 = []
    ca-central-1   = []
  }
}
