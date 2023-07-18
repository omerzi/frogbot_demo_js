output "instance_address" {
  value = element(concat(aws_db_instance.byok_database.*.address, [""]), 0)
}

output "instance_endpoint" {
  value = element(concat(aws_db_instance.byok_database.*.endpoint, [""]), 0)
}

output "instance_admin_username" {
  value = element(concat(aws_db_instance.byok_database.*.username, [""]), 0)
}

output "instance_admin_password" {
  value = element(concat(aws_db_instance.byok_database.*.password, [""]), 0)
  sensitive = true
}

//output "postgres_security_group" {
//  value = element(concat(aws_security_group.k8s_database_sg.*.id, [""]), 0)
//}
