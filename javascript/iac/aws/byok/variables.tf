variable "pg_main_region" {
  type = string
}

variable "pg_dr_region" {
  type    = string
  default = ""
}

variable "environment" {
}

variable "deploy_name" {
}

variable "service_name" {
}

variable "password" {
  default = ""
}

variable "subnets" {
  type = list(string)
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

variable "byok-arn" {
  default = ""
}

# Module      : KMS KEY
# Description : Provides a KMS customer master key.
variable "deletion_window_in_days" {
  type        = number
  default     = 10
  description = "Duration in days after which the key is deleted after destruction of the resource."
}

variable "description" {
  type        = string
  default     = "Parameter Store KMS master key"
  description = "The description of the key as viewed in AWS console."
}

variable "is_enabled" {
  type        = bool
  default     = true
  description = "Specifies whether the key is enabled."
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Specifies whether the kms is enabled or disabled."
}

variable "key_usage" {
  type    = string
  default = "ENCRYPT_DECRYPT"
  //sensitive   = true
  description = "Specifies the intended use of the key. Defaults to ENCRYPT_DECRYPT, and only symmetric encryption and decryption are supported."
}

variable "alias" {
  type        = string
  default     = ""
  description = "The display name of the alias. The name must start with the word `alias` followed by a forward slash."
}

variable "policy" {
  type    = string
  default = ""
  //sensitive   = true
  description = "A valid policy JSON document. For more information about building AWS IAM policy documents with Terraform."
}

variable "customer_master_key_spec" {
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  description = "Specifies whether the key contains a symmetric key or an asymmetric key pair and the encryption algorithms or signing algorithms that the key supports. Valid values: SYMMETRIC_DEFAULT, RSA_2048, RSA_3072, RSA_4096, ECC_NIST_P256, ECC_NIST_P384, ECC_NIST_P521, or ECC_SECG_P256K1. Defaults to SYMMETRIC_DEFAULT."
  //sensitive   = true
}

variable "customer" {
  type    = string
  default = ""
}

variable "owner_id" {
  default = ""
}

variable "sso_account" {
  default = ""
}

variable "terraform_admin" {
  default = ""
}

variable "customer_aws_account" {
  default = ""
}

variable "replication_role" {
  default = ""
}

variable "narcissus_domain_short" {
  default = ""
}