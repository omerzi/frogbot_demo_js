output "pl_nlb_arn" {
  value = var.module_enabled == 0 ? "" : try(aws_lb.pl_nlb[0].arn, "")
}

output "pl_nlb_dns" {
  value = var.module_enabled == 0 ? "" : try(aws_lb.pl_nlb[0].dns_name, "")
}

output "pl_tg_id" {
  value = var.module_enabled == 0 ? "" : try(aws_lb_target_group.pl_tg[0].id, "")
}

output "pl_tg_id_plain" {
  value = var.module_enabled == 0 ? "" : try(aws_lb_target_group.pl_tg_plain[0].id, "")
}

output "pl_service_name" {
  value = var.module_enabled == 0 ? "" : try(aws_vpc_endpoint_service.pl_service[0].service_name, "")
}

output "pl_service_id" {
  value = var.module_enabled == 0 ? "" : try(aws_vpc_endpoint_service.pl_service[0].id , "")
}

output "pl_subnets" {
  value = var.module_enabled == 0 ? [] : try(aws_subnet.privatelink.*.id , [])
}

output "dns_verify_record_zone_id" {
  value = ! var.enable_private_dns ? "" : try(aws_route53_record.pl_service_txt_Verify[0].zone_id, "")
}
output "pl_availabilityzones" {
 value = var.module_enabled == 0 ? [] : try(tolist(aws_vpc_endpoint_service.pl_service[0].availability_zones),[])
}

