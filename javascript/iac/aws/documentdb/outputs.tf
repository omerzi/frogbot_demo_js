output "master_username" {
  value = aws_docdb_cluster.default.*.master_username
}

output "master_password" {
  value     = aws_docdb_cluster.default.*.master_password
  sensitive = true
}

output "endpoint" {
  value = aws_docdb_cluster.default.*.endpoint
}

output "reader_endpoint" {
  value = aws_docdb_cluster.default.*.reader_endpoint
}

