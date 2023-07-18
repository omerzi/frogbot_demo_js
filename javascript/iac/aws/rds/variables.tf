variable "region" {
  type    = string
}

//variable "pg_dr_region" {
//  type    = string
//  default = ""
//}

//variable "dr_vpc_id" {
//  type = string
//  default = ""
//}

variable "environment" {
}

variable "deploy_name" {
}

variable "service_name" {
}

variable "password" {
  default = ""
}
variable "create_sdm_resources" {
  default = false
}
variable "multi_az" {
}

variable "option_group_name" {
}

variable "vpc_id" {
}

variable "port" {
  default = 5432
}

variable "security_groups" {
}

variable "postgres_dbs" {
}

variable "dbs_count" {
}

variable "monitoring_interval" {
}

variable "backup_retention_period" {
}

variable "auto_minor_version_upgrade" {
  default = false
}

variable "central_pg_sg" {
  default = ""
}

variable "postgresql_ing_cidr_blocks" {
}

variable "ca_cert_identifier" {
  default = "rds-ca-2019"
}

variable "project_name" {
  description = "The project in which the resource belongs. If it is not provided, the provider project is used."
  type        = string
}

variable "narcissus_domain_short" {
  type = string
}

variable "postgresql_machine_type_spec" {
  type = map(string)
}

variable "anitain_sg" {
  default = null
}
