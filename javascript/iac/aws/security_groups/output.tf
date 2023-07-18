output "k8s_security_group_id" {
  value = contains(keys(var.sg_map),"k8s") ? element(concat(aws_security_group.k8s.*.id, [""]), 0) : null
}

output "sdm_security_group_id" {
  value =contains(keys(var.sg_map),"sdm") ? element(concat(aws_security_group.sdm.*.id, [""]), 0) : null
}

output "pl_security_group_id" {
  value =contains(keys(var.sg_map),"pl_monitoring") ? element(concat(aws_security_group.pl_monitoring.*.id, [""]), 0) : null
}
