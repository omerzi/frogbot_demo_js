data "null_data_source" "local" {
  inputs = {
    enable_pl = var.isMainCluster && var.module_enabled != 0 ? var.module_enabled : 0
  }
}

resource "aws_lb" "pl_nlb" {
  count                             = data.null_data_source.local.inputs.enable_pl
  name                              = "${var.privatelink_map.BaseName}-pl-nlb"
  internal                          = lookup(var.privatelink_map.load_balancer, "lb_internal", true)
  load_balancer_type                = lookup(var.privatelink_map.load_balancer, "lb_load_balancer_type", "network")
  enable_cross_zone_load_balancing  = lookup(var.privatelink_map.load_balancer, "lb_cross_zone_load_balancing", false)
  subnets                           = concat(var.subnets, aws_subnet.privatelink.*.id)
  enable_deletion_protection        = lookup(var.privatelink_map.load_balancer, "lb_deletion_protection", false)

  tags = {
    Environment               = var.environment
  }

  depends_on = [
    aws_subnet.privatelink
  ]
}


resource "aws_lb_target_group" "pl_tg" {
  count                  = data.null_data_source.local.inputs.enable_pl
  name                   = "${var.privatelink_map.BaseName}-pl-tg"
  port                   = lookup(var.privatelink_map.target_group, "port", 30000)
  target_type            = lookup(var.privatelink_map.target_group, "target_type", "instance")
  protocol               = lookup(var.privatelink_map.target_group, "protocol", "TCP")
  vpc_id                 = var.vpc_id
  proxy_protocol_v2      = lookup(var.privatelink_map.target_group, "proxy_protocol_v2", false)
  deregistration_delay   = lookup(var.privatelink_map.target_group, "deregistration_delay", 300)

  dynamic "health_check" {
    for_each = var.privatelink_map.target_group.health_check

    content {
      protocol            = var.privatelink_map.target_group.protocol
      interval            = lookup(health_check.value, "interval", 10)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", 3)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", 3)
    }
  }

  depends_on = [
    aws_lb.pl_nlb
  ]
}


resource "aws_lb_listener" "pl_lb_listener" {
  count                 = data.null_data_source.local.inputs.enable_pl
  load_balancer_arn     = aws_lb.pl_nlb[count.index].arn
  port                  = lookup(var.privatelink_map.load_balancer, "listener_port", 80)
  protocol              = lookup(var.privatelink_map.load_balancer, "listener_protocol", "TCP")

  default_action {
    type                = lookup(var.privatelink_map.load_balancer, "listener_action_type", "forward")
    target_group_arn    = aws_lb_target_group.pl_tg[count.index].arn
  }

  depends_on = [
    aws_lb.pl_nlb,
    aws_lb_target_group.pl_tg
  ]
}


###########################################################################################

resource "aws_lb_target_group" "pl_tg_plain" {
  count                  = data.null_data_source.local.inputs.enable_pl
  name                   = "${var.privatelink_map.BaseName}-pl-tg-plain"
  port                   = lookup(var.privatelink_map.target_group, "port_plain", 30000)
  target_type            = lookup(var.privatelink_map.target_group, "target_type", "instance")
  protocol               = lookup(var.privatelink_map.target_group, "protocol", "TCP")
  vpc_id                 = var.vpc_id
  proxy_protocol_v2      = lookup(var.privatelink_map.target_group, "proxy_protocol_v2", false)
  deregistration_delay   = lookup(var.privatelink_map.target_group, "deregistration_delay", 300)

  dynamic "health_check" {
    for_each = var.privatelink_map.target_group.health_check

    content {
      protocol            = var.privatelink_map.target_group.protocol
      interval            = lookup(health_check.value, "interval", 10)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", 3)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", 3)
    }
  }

  depends_on = [
    aws_lb.pl_nlb
  ]
}


resource "aws_lb_listener" "pl_lb_listener_plain" {
  count                 = data.null_data_source.local.inputs.enable_pl
  load_balancer_arn     = aws_lb.pl_nlb[count.index].arn
  port                  = lookup(var.privatelink_map.load_balancer, "listener_port_plain", 80)
  protocol              = lookup(var.privatelink_map.load_balancer, "listener_protocol", "TCP")

  default_action {
    type                = lookup(var.privatelink_map.load_balancer, "listener_action_type", "forward")
    target_group_arn    = aws_lb_target_group.pl_tg_plain[count.index].arn
  }

  depends_on = [
    aws_lb.pl_nlb,
    aws_lb_target_group.pl_tg_plain
  ]
}
#################################################################################

resource "aws_vpc_endpoint_service" "pl_service" {
  count                       = data.null_data_source.local.inputs.enable_pl
  acceptance_required         = lookup(var.privatelink_map.pl_service, "acceptance_required", true)
  private_dns_name            = ! var.enable_private_dns ? "" : "*.${var.pl_domain}"

  network_load_balancer_arns  = [
    aws_lb.pl_nlb[count.index].arn
  ]

  depends_on = [
    aws_lb.pl_nlb
  ]
}

resource "aws_vpc_endpoint_service_allowed_principal" "allow_all_pl_discovery" {
  count                       = data.null_data_source.local.inputs.enable_pl
  vpc_endpoint_service_id     = aws_vpc_endpoint_service.pl_service[count.index].id
  principal_arn               = "*"

  depends_on = [
    aws_vpc_endpoint_service.pl_service
  ]
}

data "aws_route53_zone" "jfrog_domain_zone_id" {
  count    = data.null_data_source.local.inputs.enable_pl != 0 && var.zone_id == "" && ! var.enable_private_dns ? 1 : 0
  name     = "${var.pl_domain}."

  depends_on = [
    aws_vpc_endpoint_service.pl_service
  ]
}

resource "aws_route53_record" "pl_service_txt_Verify" {
  count       = data.null_data_source.local.inputs.enable_pl != 0 && var.module_enabled != 0 && var.enable_private_dns ? var.module_enabled : 0
  name        = aws_vpc_endpoint_service.pl_service[0].private_dns_name_configuration[0].name
  type        = aws_vpc_endpoint_service.pl_service[0].private_dns_name_configuration[0].type
  zone_id     = var.zone_id == "" ? data.aws_route53_zone.jfrog_domain_zone_id[count.index].zone_id : var.zone_id
  ttl         = 300

  records     = [
    aws_vpc_endpoint_service.pl_service[0].private_dns_name_configuration[0].value
  ]

  depends_on = [
    data.aws_route53_zone.jfrog_domain_zone_id
  ]
}