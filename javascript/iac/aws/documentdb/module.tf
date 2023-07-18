resource "random_string" "master-password" {
  count = var.module_enabled ? 1 : 0
  length = 16
  special = false
}

resource "aws_docdb_cluster_instance" "cluster-instances" {
  count              = var.module_enabled ? var.num_nodes : 0
  apply_immediately  = var.apply_immediately
  cluster_identifier = aws_docdb_cluster.default[0].id
  engine             = var.engine
  instance_class     = var.node_type
}

resource "aws_docdb_cluster" "default" {
  count                           = var.module_enabled ? 1 : 0
  apply_immediately               = var.apply_immediately
  cluster_identifier              = var.deploy_name
  db_subnet_group_name            = var.deploy_name
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  engine                          = var.engine
  engine_version                  = var.engine_version
  master_username                 = var.master_username
  master_password                 = random_string.master-password[0].result
  port                            = var.port
  final_snapshot_identifier       = var.deploy_name
  skip_final_snapshot             = var.skip_final_snapshot
  vpc_security_group_ids = [
    aws_security_group.default[0].id,
  ]
}

resource "aws_security_group" "default" {
  count  = var.module_enabled ? 1 : 0
  name   = "${var.deploy_name}-${var.ingress_rules}"
  vpc_id = var.vpc_id

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.deploy_name}-${var.ingress_rules}"
  }
}

