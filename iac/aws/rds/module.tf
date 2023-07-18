data "aws_region" "current" {}

data "null_data_source" "disk_default" {
  count = var.dbs_count
  inputs = {
    allocated_storage = lookup(var.postgres_dbs[count.index], "disk_size_gb" , 500)
  }
}

//data "null_data_source" "locals" {
//  inputs = {
//    main_region = var.pg_main_region
//    dr_region = data.null_data_source.dr_flags.inputs.isDR ? var.pg_dr_region : var.pg_main_region
//  }
//}

//provider "aws" {
//  region  = data.null_data_source.locals.inputs.main_region
//  alias   = "main_provider"
//}

data "null_data_source" "locals_per_db" {
  count = var.dbs_count
  inputs = {
    max_allocated_storage = data.null_data_source.disk_default[count.index].outputs.allocated_storage < 1000 ? data.null_data_source.disk_default[count.index].outputs.allocated_storage*1.5 : data.null_data_source.disk_default[count.index].outputs.allocated_storage*1.25
//    pg_base_name = lookup(var.postgres_dbs[count.index], "name", "${var.deploy_name}-${data.null_data_source.locals.inputs.main_region}-${var.service_name}-${count.index+1}")
    pg_base_name = lookup(var.postgres_dbs[count.index], "name", "${var.deploy_name}-${var.region}-${var.service_name}-${count.index+1}")
  }
}

resource "random_password" "k8s_database_password" {
  count   = var.dbs_count != 0 && var.service_name != "central-postgresql" ? 1 : 0
  length      = 16
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  min_upper   = 2
  number      = true
  special     = true
  upper       = true
}

resource "aws_db_parameter_group" "k8s_database_pg" {
//  provider  = aws.main_provider
  count     = var.dbs_count
  name      = "${data.null_data_source.locals_per_db[count.index].inputs.pg_base_name}-pg"
  family    = lookup(var.postgres_dbs[count.index], "param_group_family", "postgres12")


  dynamic "parameter" {
    for_each = lookup(var.postgres_dbs[count.index], "parameters", {})
    iterator = postgres_parameter
    content {
      name         = postgres_parameter.value.name
      value        = postgres_parameter.value.value
      apply_method = try(postgres_parameter.value.apply_method,"pending-reboot")
    }
  }
  tags = merge(data.null_data_source.postgresql_common_tags[count.index].inputs, {usedFor = data.null_data_source.locals_per_db[count.index].inputs.pg_base_name})
}

resource "aws_security_group" "k8s_database_sg" {
//  provider  = aws.main_provider
  count     = var.dbs_count != 0 && var.service_name != "central-postgresql" ? 1 : 0
  name      = "${var.deploy_name}-${var.region}-${var.service_name}"
//  name      = "${var.deploy_name}-${data.null_data_source.locals.inputs.main_region}-${var.service_name}"
  vpc_id    = var.vpc_id

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    self            = true
    security_groups = var.security_groups
    cidr_blocks     = var.postgresql_ing_cidr_blocks
  }

  dynamic ingress {
    for_each    =  var.anitain_sg != null ? [1] : []
    content {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = var.anitain_sg
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = data.null_data_source.postgresql_common_tags[count.index].inputs
}

data "aws_iam_role" "k8s_database_rds_monitoring_role" {
//  provider = aws.main_provider
  name = "rds-monitoring-role"
}

resource "aws_db_instance" "k8s_database" {
//  provider                        = aws.main_provider
  count                           = var.dbs_count
  allocated_storage               = data.null_data_source.disk_default[count.index].outputs.allocated_storage
  max_allocated_storage           = lookup(var.postgres_dbs[count.index] , "max_allocated_storage",ceil(data.null_data_source.locals_per_db[count.index].outputs.max_allocated_storage))
  engine                          = lookup(var.postgres_dbs[count.index] , "engine", "postgres")
  engine_version                  = lookup(var.postgres_dbs[count.index] , "engine_version", 12.5)
  identifier                      = data.null_data_source.locals_per_db[count.index].inputs.pg_base_name
  instance_class                  = var.postgres_dbs[count.index]["instance_class"]
  maintenance_window              = lookup(var.postgres_dbs[count.index] , "maintenance_window", "sat:01:00-sat:01:30") # UTC
  backup_window                   = lookup(var.postgres_dbs[count.index] , "backup_window", "08:30-09:00") # UTC
  backup_retention_period         = lookup(var.postgres_dbs[count.index] , "backup_retention_period" , var.backup_retention_period)
  monitoring_interval             = lookup(var.postgres_dbs[count.index] , "monitoring_interval" , var.monitoring_interval)
  monitoring_role_arn             = lookup(var.postgres_dbs[count.index] , "monitoring_interval" , var.monitoring_interval) != 0 ? data.aws_iam_role.k8s_database_rds_monitoring_role.arn : ""
  username                        = lookup(var.postgres_dbs[count.index] , "user_name" , "root")
  iops                            = lookup(var.postgres_dbs[count.index] , "iops",null) 
  storage_throughput              = lookup(var.postgres_dbs[count.index] , "throughput",null)
  password                        = var.password == "" ? random_password.k8s_database_password[0].result : var.password
  port                            = var.port
  multi_az                        = var.multi_az
  storage_type                    = lookup(var.postgres_dbs[count.index] , "storage_type" , "gp2")
  ca_cert_identifier              = lookup(var.postgres_dbs[count.index] , "ca_cert_identifier", var.ca_cert_identifier)
  db_subnet_group_name            = lookup(var.postgres_dbs[count.index] , "db_subnet_group_name" , "${var.deploy_name}-${var.region}") 
//  db_subnet_group_name            = "${var.deploy_name}-${data.null_data_source.locals.inputs.main_region}"
  parameter_group_name            = aws_db_parameter_group.k8s_database_pg[count.index].name
//  option_group_name               = var.option_group_name
  vpc_security_group_ids          = var.central_pg_sg == "" ? concat(lookup(var.postgres_dbs[count.index] , "additional_sg" ,[]),[aws_security_group.k8s_database_sg[0].id]) : [var.central_pg_sg]
  copy_tags_to_snapshot           = true
  storage_encrypted               = lookup(var.postgres_dbs[count.index] , "storage_encrypted", true)
  auto_minor_version_upgrade      = lookup(var.postgres_dbs[count.index] , "auto_minor_version_upgrade", var.auto_minor_version_upgrade)
  performance_insights_enabled    = lookup(var.postgres_dbs[count.index] , "performance_insights_enabled", true)
  enabled_cloudwatch_logs_exports = lookup(var.postgres_dbs[count.index] , "enabled_cloudwatch_logs_exports", [])
  apply_immediately               = lookup(var.postgres_dbs[count.index] , "apply_immediately", true)
  deletion_protection             = lookup(var.postgres_dbs[count.index] , "deletion_protection", true)
  skip_final_snapshot             = lookup(var.postgres_dbs[count.index] , "skip_final_snapshot", false)

  tags = merge(try(data.null_data_source.postgresql_dev_common_tags[count.index].inputs,{}),data.null_data_source.postgresql_instance_tags[count.index].inputs)
  depends_on = [
    random_password.k8s_database_password,
    aws_db_parameter_group.k8s_database_pg,
    aws_security_group.k8s_database_sg
  ]

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      latest_restorable_time
    ]
  }
}

data "null_data_source" "postgresql_common_tags" {
  count     = var.dbs_count
  inputs = {
    name          = lookup(var.postgres_dbs[count.index], "name", "${var.deploy_name}-${var.region}-${var.service_name}")
    cloud_project = lower(var.project_name)
    environment   = lower(var.environment)
    jfrog_region  = lower(var.narcissus_domain_short)
    cloud_region  = lower(var.region)
    service       = lower(var.service_name)
    terraform     = "true"
  }
}

data "null_data_source" "postgresql_dev_common_tags" {
  count     = var.dbs_count > 0 && length(regexall("jfrog-dev",var.project_name)) > 0 ? var.dbs_count : 0
  inputs = {
    monitor = "d2c"
  }
}

data "null_data_source" "postgresql_instance_tags" {
  count     = var.dbs_count
  inputs = merge(
    data.null_data_source.postgresql_common_tags[count.index].inputs,
    {
      name            = lookup(var.postgres_dbs[count.index], "name", "${var.deploy_name}-${var.region}-${var.service_name}-${count.index+1}")
      instance_class  = var.postgres_dbs[count.index]["instance_class"]
      db_cpu          = element(split(",", lookup(var.postgresql_machine_type_spec,"${var.postgres_dbs[count.index]["instance_class"]}","none,none") )  ,0)
      db_memory       = element(split(",", lookup(var.postgresql_machine_type_spec,"${var.postgres_dbs[count.index]["instance_class"]}","none,none") )  ,1)
      db_storage_gb   = lookup(var.postgres_dbs[count.index], "disk_size_gb" , 500)
      engine_version  = lookup(var.postgres_dbs[count.index] , "engine_version", 12.5)
      customer        = lower(contains(keys(var.postgres_dbs[count.index].tags), "customer") ? var.postgres_dbs[count.index].tags["customer"] : "shared")
      purpose         = lower(contains(keys(var.postgres_dbs[count.index].tags), "purpose") ? var.postgres_dbs[count.index].tags["purpose"] : "all-jfrog-apps")
      workload_type   = lower(contains(keys(var.postgres_dbs[count.index].tags), "workload_type") ? var.postgres_dbs[count.index].tags["workload_type"] : "main")
      application     = lower(contains(keys(var.postgres_dbs[count.index].tags), "application") ? var.postgres_dbs[count.index].tags["application"] : "common") 
      owner           = lower(contains(keys(var.postgres_dbs[count.index].tags), "owner") ? var.postgres_dbs[count.index].tags["owner"] : "devops")
    }
  )
}

resource "sdm_resource" "postgres" {
  count = var.create_sdm_resources ? var.dbs_count : 0 
    postgres {
        name = "AWS-${lookup(var.postgres_dbs[count.index], "sdm_name",var.postgres_dbs[count.index].name)}"
        hostname = lookup(var.postgres_dbs[count.index],"sdm_hostname", aws_db_instance.k8s_database[count.index].address)
        database = "postgres"
        username = lookup(var.postgres_dbs[count.index],"sdm_username", aws_db_instance.k8s_database[count.index].username)
        password = random_password.k8s_database_password[0].result
        port = 5432
        tags = merge(lookup(var.postgres_dbs[count.index], "sdm_tags", null), {region=var.region}, {env = var.environment})
    }
}

