output "file_system_id" {
  value = element(concat(aws_efs_file_system.efs.*.id, [""]), 0)
}

output "dns_name" {
  value = element(concat(aws_efs_file_system.efs.*.dns_name, [""]), 0)
}

