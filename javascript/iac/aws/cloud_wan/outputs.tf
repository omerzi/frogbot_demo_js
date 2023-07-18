output "core_network_arn"{
    value = var.create_core_network != false ?  awscc_networkmanager_core_network.core_network[0].core_network_arn : null
}

output "core_network_id"{
    value = var.create_core_network != false ?  awscc_networkmanager_core_network.core_network[0].core_network_id : null
}
output "awscc_networkmanager_global_network" {
  value = awscc_networkmanager_global_network.global_network[0].id
}