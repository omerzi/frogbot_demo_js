variable "module_enabled" {
  default = true
}

variable "logstash_vpc_id" {
  default = ""
}

variable "cidr_blocks_list" {
  default = []
}

variable "to_port" {}

variable "from_port" {}