data "null_data_source" "disk_default" {
  count = var.dbs_count
  inputs = {
    allocated_storage = lookup(var.postgres_dbs[count.index], "disk_size_gb", 500)
  }
}

data "null_data_source" "locals" {
  inputs = {
    main_region = var.pg_main_region
    //dr_region = data.null_data_source.dr_flags.inputs.isDR ? var.pg_dr_region : var.pg_main_region
  }
}

provider "aws" {
  region = data.null_data_source.locals.inputs.main_region
  alias  = "main_provider"
}

data "null_data_source" "locals_per_db" {
  count = var.dbs_count
  inputs = {
    max_allocated_storage = data.null_data_source.disk_default[count.index].outputs.allocated_storage < 1000 ? data.null_data_source.disk_default[count.index].outputs.allocated_storage * 1.5 : data.null_data_source.disk_default[count.index].outputs.allocated_storage * 1.25
    pg_base_name          = lookup(var.postgres_dbs[count.index], "name", "byok-${var.environment}-${data.null_data_source.locals.inputs.main_region}-${var.service_name}-${count.index + 1}-${var.postgres_dbs[count.index].tags["customer"]}")
  }
}

resource "random_password" "byok_database_password" {
  count            = var.dbs_count != 0 && var.service_name != "central-postgresql" ? 1 : 0
  length           = 16
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "_%@"
  number           = true
  special          = true
  upper            = true
}

resource "aws_db_parameter_group" "byok_database_pg" {
  count    = var.dbs_count
  name     = lookup(var.postgres_dbs[count.index],"pg_name","${data.null_data_source.locals_per_db[count.index].inputs.pg_base_name}-pg")
  family   = lookup(var.postgres_dbs[count.index], "param_group_family", "postgres12")

  dynamic "parameter" {
    for_each = lookup(var.postgres_dbs[count.index], "parameters", {})
    iterator = postgres_parameter
    content {
      name         = postgres_parameter.key
      value        = postgres_parameter.value
      apply_method = "pending-reboot"
    }
  }
  tags = {
    environment     = var.environment
    service         = var.service_name
    terraform       = "True"
    usedFor         = lookup(var.postgres_dbs[count.index],"name",data.null_data_source.locals_per_db[count.index].inputs.pg_base_name)
    cloud_region    = data.null_data_source.locals.inputs.main_region

  }
}

data "aws_iam_role" "byok_database_rds_monitoring_role" {
  name     = "rds-monitoring-role"
}

resource "aws_db_instance" "byok_database" {
  count                   = var.dbs_count
  allocated_storage       = data.null_data_source.disk_default[count.index].outputs.allocated_storage
  max_allocated_storage   = ceil(data.null_data_source.locals_per_db[count.index].outputs.max_allocated_storage)
  engine                  = lookup(var.postgres_dbs[count.index], "engine", "postgres")
  engine_version          = lookup(var.postgres_dbs[count.index], "engine_version", 12.5)
  identifier              = lookup(var.postgres_dbs[count.index], "name" ,data.null_data_source.locals_per_db[count.index].inputs.pg_base_name)
  instance_class          = var.postgres_dbs[count.index]["instance_class"]
  maintenance_window      = lookup(var.postgres_dbs[count.index], "maintenance_window", "sun:09:30-sun:10:00")
  backup_window           = lookup(var.postgres_dbs[count.index], "backup_window", "08:30-09:00")
  backup_retention_period = lookup(var.postgres_dbs[count.index], "backup_retention_period", var.backup_retention_period)
  monitoring_interval     = lookup(var.postgres_dbs[count.index], "monitoring_interval", var.monitoring_interval)
  monitoring_role_arn     = lookup(var.postgres_dbs[count.index], "monitoring_interval", var.monitoring_interval) != 0 ? data.aws_iam_role.byok_database_rds_monitoring_role.arn : ""
  username                = lookup(var.postgres_dbs[count.index], "user_name", "root")
  password                = var.password == "" ? random_password.byok_database_password[0].result : var.password
  port                    = var.port
  multi_az                = var.multi_az
  ca_cert_identifier      = lookup(var.postgres_dbs[count.index], "ca_cert_identifier", var.ca_cert_identifier)
  db_subnet_group_name    = "${var.deploy_name}-${data.null_data_source.locals.inputs.main_region}"
  parameter_group_name    = aws_db_parameter_group.byok_database_pg[count.index].name
  //  option_group_name               = var.option_group_name
  vpc_security_group_ids = [
    var.security_groups] //central_pg_sg == "" ? [aws_security_group.byok_database_sg[0].id] : [var.central_pg_sg]
  deletion_protection             = true
  copy_tags_to_snapshot           = true
  storage_encrypted               = lookup(var.postgres_dbs[count.index], "storage_encrypted", true)
  kms_key_id                      = aws_kms_key.byok-kms-key.arn
  auto_minor_version_upgrade      = lookup(var.postgres_dbs[count.index], "auto_minor_version_upgrade", var.auto_minor_version_upgrade)
  performance_insights_enabled    = lookup(var.postgres_dbs[count.index], "performance_insights_enabled", true)
  enabled_cloudwatch_logs_exports = lookup(var.postgres_dbs[count.index], "enabled_cloudwatch_logs_exports", [])
  skip_final_snapshot             = true
  final_snapshot_identifier       = "${var.postgres_dbs[count.index].tags["customer"]}-backup"
  tags = {
    application = var.postgres_dbs[count.index].tags["application"]
    environment = var.environment
    service     = var.service_name
    terraform   = "True"
    cloud_region    = data.null_data_source.locals.inputs.main_region
    customer    = var.postgres_dbs[count.index].tags["customer"]
    workload_type   = lower(contains(keys(var.postgres_dbs[count.index].tags), "workload_type") ? var.postgres_dbs[count.index].tags["workload_type"] : "main")
    purpose         = lower(contains(keys(var.postgres_dbs[count.index].tags), "purpose") ? var.postgres_dbs[count.index].tags["purpose"] : "msb")
    name            = lookup(var.postgres_dbs[count.index], "name", "${var.deploy_name}-${var.pg_main_region}-${var.service_name}-${count.index+1}")
    jfrog_region  = lower(var.narcissus_domain_short)

  }
    
  depends_on = [
    random_password.byok_database_password,
    aws_db_parameter_group.byok_database_pg,
    //aws_security_group.byok_database_sg,
    aws_kms_key.byok-kms-key
  ]
}

resource "aws_kms_key" "byok-kms-key" {
  description              = "Byok KMS Keys for Data Encryption"
  enable_key_rotation      = true
  key_usage                = var.key_usage
  deletion_window_in_days  = var.deletion_window_in_days
  is_enabled               = var.is_enabled
  customer_master_key_spec = var.customer_master_key_spec
  //policy                   = var.policy
  tags = {
    Name = "byok-kms-keys"
  }

  policy = <<EOF
{
    "Id": "key-consolepolicy-3",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner_id}:role/aws-reserved/sso.amazonaws.com/${var.sso_account}",
                    "arn:aws:iam::${var.owner_id}:role/service-role/${var.replication_role}",
                    "arn:aws:iam::${var.owner_id}:user/${var.terraform_admin}",
                    "arn:aws:iam::${var.owner_id}:user/${var.customer_aws_account}",
                    "arn:aws:iam::${var.owner_id}:root"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow access for Key Administrators",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner_id}:role/aws-reserved/sso.amazonaws.com/${var.sso_account}",
                    "arn:aws:iam::${var.owner_id}:role/service-role/${var.replication_role}",
                    "arn:aws:iam::${var.owner_id}:user/${var.terraform_admin}",
                    "arn:aws:iam::${var.owner_id}:user/${var.customer_aws_account}",
                    "arn:aws:iam::${var.owner_id}:root"
                ]
            },
            "Action": [
                "kms:Create*",
                "kms:Describe*",
                "kms:Enable*",
                "kms:List*",
                "kms:Put*",
                "kms:Update*",
                "kms:Revoke*",
                "kms:Disable*",
                "kms:Get*",
                "kms:Delete*",
                "kms:TagResource",
                "kms:UntagResource",
                "kms:ScheduleKeyDeletion",
                "kms:CancelKeyDeletion"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow use of the key",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner_id}:role/aws-reserved/sso.amazonaws.com/${var.sso_account}",
                    "arn:aws:iam::${var.owner_id}:role/service-role/${var.replication_role}",
                    "arn:aws:iam::${var.owner_id}:user/${var.terraform_admin}",
                    "arn:aws:iam::${var.owner_id}:user/${var.customer_aws_account}",
                    "arn:aws:iam::${var.owner_id}:root"
                ]
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow attachment of persistent resources",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner_id}:role/aws-reserved/sso.amazonaws.com/${var.sso_account}",
                    "arn:aws:iam::${var.owner_id}:role/service-role/${var.replication_role}",
                    "arn:aws:iam::${var.owner_id}:user/${var.terraform_admin}",
                    "arn:aws:iam::${var.owner_id}:user/${var.customer_aws_account}",
                    "arn:aws:iam::${var.owner_id}:root"
                ]
            },
            "Action": [
                "kms:CreateGrant",
                "kms:ListGrants",
                "kms:RevokeGrant"
            ],
            "Resource": "*",
            "Condition": {
                "Bool": {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        }
    ]
}
EOF
}

resource "aws_kms_alias" "byok-kms-alias" {
  target_key_id = aws_kms_key.byok-kms-key.key_id
  name          = "alias/byok-key-${var.customer}-${var.pg_main_region}"
  depends_on = [
    aws_kms_key.byok-kms-key
  ]
}
