output "zookeeper_connect_string" {
  value = aws_msk_cluster.msk.*.zookeeper_connect_string
}

output "bootstrap_brokers" {
  description = "Plaintext connection host:port pairs"
  value       = aws_msk_cluster.msk.*.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.msk.*.bootstrap_brokers_tls
}

//output "ip_addrs" {
//  value = "${join(",", data.dns_a_record_set.dns_record.addrs)}"
//}
//
//output "eni_id" {
//  value = "${data.aws_network_interfaces.network_interfaces.ids[0]}"
//}
//output "dns_record_test" {
//  value = "${data.dns_a_record_set.dns_record_test.addrs}"
//}
