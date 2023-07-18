resource "aws_security_group" "sg" {
  count  = var.module_enabled ? 1 : 0
  name   = "aws_msk_sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.ingress_cidr_blocks, "192.168.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.deploy_name
  }
}

resource "aws_kms_key" "kms" {
  count       = var.module_enabled ? 1 : 0
  description = "msk-key"
}

resource "aws_cloudwatch_log_group" "log" {
  count = var.module_enabled ? 1 : 0
  name  = "msk_broker_logs"
}

resource "aws_s3_bucket" "bucket" {
  count  = var.module_enabled ? 1 : 0
  bucket = "jfrog-msk-broker-logs"
  acl    = "private"
}

resource "aws_msk_cluster" "msk" {
  count                  = var.module_enabled ? 1 : 0
  cluster_name           = var.deploy_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.msk_nodes

  broker_node_group_info {
    instance_type   = var.instance_type
    ebs_volume_size = var.ebs_volume_size
    client_subnets  = var.subnets
    security_groups = [aws_security_group.sg[0].id]
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kms[0].arn
    encryption_in_transit {
      client_broker = "TLS"
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.log[0].name
      }

      s3 {
        enabled = true
        bucket  = aws_s3_bucket.bucket[0].id
        prefix  = "logs/msk-"
      }
    }
  }

  tags = {
    Environment = var.environment
  }
  lifecycle {
    ignore_changes = [configuration_info]
  }
}

locals {
  brokers = sort(
    split(
      ",",
      replace(
        join(",", aws_msk_cluster.msk.*.bootstrap_brokers_tls),
        ":9094",
        "",
      ),
    ),
  )
  zookeeper = sort(
    split(
      ",",
      replace(
        join(",", aws_msk_cluster.msk.*.zookeeper_connect_string),
        ":2181",
        "",
      ),
    ),
  )
}

//  zookeeper

data "dns_a_record_set" "dns_record_zookeeper" {
  count = var.module_enabled ? var.msk_nodes : 0
  host  = local.zookeeper[count.index]
}

data "aws_network_interfaces" "network_interfaces_zookeeper" {
  count = var.module_enabled ? var.msk_nodes : 0
  filter {
    name = "private-ip-address"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibility in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    values = [element(
      flatten(data.dns_a_record_set.dns_record_zookeeper.*.addrs),
      count.index,
    )]
  }
}

resource "aws_eip" "eip_zookeeper" {
  count = var.module_enabled ? var.msk_nodes : 0
  vpc   = true
  network_interface = element(
    flatten(
      data.aws_network_interfaces.network_interfaces_zookeeper.*.ids,
    ),
    count.index,
  )
  associate_with_private_ip = element(
    flatten(data.dns_a_record_set.dns_record_zookeeper.*.addrs),
    count.index,
  )
  tags = {
    Name = element(
      flatten(data.dns_a_record_set.dns_record_zookeeper.*.host),
      count.index,
    )
    Environment = var.environment
  }
}

//  brokers

data "dns_a_record_set" "dns_record_brokers" {
  count = var.module_enabled ? var.msk_nodes : 0
  host  = local.brokers[count.index]
}

data "aws_network_interfaces" "network_interfaces_brokers" {
  count = var.module_enabled ? var.msk_nodes : 0
  filter {
    name = "private-ip-address"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibility in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    values = [element(
      flatten(data.dns_a_record_set.dns_record_brokers.*.addrs),
      count.index,
    )]
  }
}

resource "aws_eip" "eip_brokers" {
  count = var.module_enabled ? var.msk_nodes : 0
  vpc   = true
  network_interface = element(
    flatten(data.aws_network_interfaces.network_interfaces_brokers.*.ids),
    count.index,
  )
  associate_with_private_ip = element(
    flatten(data.dns_a_record_set.dns_record_brokers.*.addrs),
    count.index,
  )
  tags = {
    Name = element(
      flatten(data.dns_a_record_set.dns_record_brokers.*.host),
      count.index,
    )
    Environment = var.environment
  }
}

