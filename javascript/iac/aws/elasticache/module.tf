resource "aws_elasticache_subnet_group" "default" {
  count      = var.module_enabled ? 1 : 0
  name       = "${local.replication_group_id}-elasticache"
  subnet_ids = var.subnets
}

resource "aws_elasticache_replication_group" "default" {
  count = var.module_enabled ? 1 : 0

  // The maximum length of the replication group id is 20 characters
  replication_group_id          = local.replication_group_id
  replication_group_description = "replication group for ${local.replication_group_id}"
  node_type                     = var.node_type
  port                          = var.port
  subnet_group_name             = aws_elasticache_subnet_group.default[0].name
  security_group_ids = [
    aws_security_group.default[0].id,
  ]
  parameter_group_name       = local.default_parameter_group_name
  automatic_failover_enabled = true
  engine                     = var.engine
  engine_version             = var.engine_version
  apply_immediately          = var.apply_immediately

  cluster_mode {
    replicas_per_node_group = var.replicas_per_node_group
    num_node_groups         = var.num_node_groups
  }
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

