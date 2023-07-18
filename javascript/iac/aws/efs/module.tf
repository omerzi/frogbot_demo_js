resource "aws_efs_file_system" "efs" {
  count                           = var.module_enabled ? 1 : 0
  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.provisioned_throughput_mb
  encrypted                       = "true"

  tags = {
    Name        = "${var.deploy_name}-${var.region}"
    Environment = var.environment
    Terraform   = "true"
  }
  lifecycle {
    ignore_changes = [
      encrypted
    ]
  }
}

resource "aws_efs_mount_target" "efs" {
  count           = var.module_enabled ? var.az_count : 0
  file_system_id  = aws_efs_file_system.efs[0].id
  subnet_id       = length(var.efs_subnets_override) == 0 ? element(var.subnets, count.index) : element(var.efs_subnets_override, count.index)
  security_groups = [aws_security_group.efs[0].id]
}

resource "aws_security_group" "efs" {
  count       = var.module_enabled ? 1 : 0
  name        = "${var.deploy_name}-${var.region}-efs"
  description = "Allow NFS traffic."
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  dynamic "ingress" {
    for_each = var.security_groups

    content {
      from_port       = "2049"
      to_port         = "2049"
      protocol        = "tcp"
      security_groups = var.security_groups
      cidr_blocks     = var.efs_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.deploy_name}-${var.region}-efs"
    Environment = var.environment
    Terraform   = "true"
  }
}

