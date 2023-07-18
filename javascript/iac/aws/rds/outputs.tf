output "instance_address" {
  value = element(concat(aws_db_instance.k8s_database.*.address, [""]), 0)
}

output "instance_endpoint" {
  value = element(concat(aws_db_instance.k8s_database.*.endpoint, [""]), 0)
}

output "instance_admin_username" {
  value = element(concat(aws_db_instance.k8s_database.*.username, [""]), 0)
}

output "instance_admin_password" {
  value = element(concat(aws_db_instance.k8s_database.*.password, [""]), 0)
  sensitive = true
}

output "postgres_security_group" {
  value = element(concat(aws_security_group.k8s_database_sg.*.id, [""]), 0)
}

output "region" {
  value = var.region
}
