//data "null_data_source" "dr_flags" {
//  inputs = {
//    isDR = var.pg_dr_region != "" && var.service_name != "central-postgresql" ? true : false
//  }
//}
//
provider "aws" {
  region = var.region
  alias = "dr_provider"
}
//
//data "null_data_source" "dr_locals" {
//  count = data.null_data_source.dr_flags.inputs.isDR ? var.dbs_count : 0
//  inputs = {
//    dr_pg_base_name = lookup(var.postgres_dbs[count.index].replica, "name", "${var.deploy_name}-${data.null_data_source.locals.inputs.main_region}-${var.service_name}-${count.index+1}-dr")
//  }
//}
//
//resource "aws_db_parameter_group" "k8s_database_dr_pg" {
//  provider    = aws.dr_provider
//  count       = data.null_data_source.dr_flags.inputs.isDR ? var.dbs_count : 0
//  name        = "${data.null_data_source.dr_locals[count.index].inputs.dr_pg_base_name}-pg"
//  family      = aws_db_parameter_group.k8s_database_pg[count.index].family
//
//  dynamic "parameter" {
//    for_each = lookup(var.postgres_dbs[count.index], "parameters", {})
//    iterator = postgres_parameter
//    content {
//      name         = postgres_parameter.key
//      value        = postgres_parameter.value
//      apply_method = "pending-reboot"
//    }
//  }
//  tags = {
//    Environment = var.environment
//    Service     = "${var.service_name}-dr"
//    Terraform   = "True"
//    usedFor     = data.null_data_source.dr_locals[count.index].inputs.dr_pg_base_name
//    Region      = data.null_data_source.locals.inputs.dr_region
//  }
//}
//
//data "aws_kms_key" "dr_region_kms" {
//  key_id = "alias/aws/rds"
//  provider = aws.dr_provider
//}
//
//resource "aws_db_instance" "k8s_database_dr" {
//  provider                        = aws.dr_provider
//  count                           = data.null_data_source.dr_flags.inputs.isDR ? var.dbs_count : 0
//  replicate_source_db             = aws_db_instance.k8s_database[count.index].arn
//  allocated_storage               = aws_db_instance.k8s_database[count.index].allocated_storage
//  max_allocated_storage           = aws_db_instance.k8s_database[count.index].max_allocated_storage
//  engine                          = aws_db_instance.k8s_database[count.index].engine
//  engine_version                  = lookup(var.postgres_dbs[count.index] , "engine_version", 12.6)
//  identifier                      = data.null_data_source.dr_locals[count.index].inputs.dr_pg_base_name
////  instance_class                  = aws_db_instance.k8s_database[count.index].instance_class
//  instance_class                  = "db.m5.large"
//  maintenance_window              = aws_db_instance.k8s_database[count.index].maintenance_window
//  port                            = aws_db_instance.k8s_database[count.index].port
////  multi_az                        = aws_db_instance.k8s_database[count.index].multi_az
//  multi_az                        = false
////  ca_cert_identifier              = aws_db_instance.k8s_database[count.index].ca_cert_identifier
////  db_subnet_group_name            = "${var.deploy_name}-${var.pg_dr_region}"
//  parameter_group_name            = aws_db_parameter_group.k8s_database_dr_pg[count.index].name
////  option_group_name               = var.option_group_name
//  deletion_protection             = true
//  storage_encrypted               = lookup(var.postgres_dbs[count.index] , "storage_encrypted", true)
//  kms_key_id                      = lookup(var.postgres_dbs[count.index] , "storage_encrypted") ? data.aws_kms_key.dr_region_kms.arn : null
//  auto_minor_version_upgrade      = aws_db_instance.k8s_database[count.index].auto_minor_version_upgrade
//  enabled_cloudwatch_logs_exports = []
//  tags = {
//    application     = var.postgres_dbs[count.index].tags["application"]
//    Environment     = var.environment
//    Service         = "${var.service_name}-dr"
//    Terraform       = "True"
//    Region          = data.null_data_source.locals.inputs.dr_region
//  }
//  depends_on = [
//    aws_db_instance.k8s_database
//  ]
//  lifecycle {
//    ignore_changes = [
//      password,
//      engine_version // TODO: Must revert once master upgraded
//    ]
//  }
//}
