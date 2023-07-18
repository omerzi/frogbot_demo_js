
output "sshproxy_security_group_id" {
  value = var.create_security_groups ? element(concat(aws_security_group.sshproxy.*.id, [""]), 0) : null
}

output "sdm_security_group_id" {
  value = var.create_security_groups ? element(concat(aws_security_group.sdm.*.id, [""]), 0) : null
}

output "builders_security_group_id" {
  value = var.create_security_groups ? element(concat(aws_security_group.builders.*.id, [""]), 0) : null
}
output "sdm_gateway_listen_address" {
  value = "sshproxy-aws-${var.deploy_name}-${var.region}.jfrog.net:5000"
}
output "sdm_gateway_name" {
  value = "AWS-${var.deploy_name}-${var.region}" 
}
output "ssh_proxy_public_ip" {
  value = aws_eip.sshproxy.*.public_ip
}
