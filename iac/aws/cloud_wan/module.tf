resource "awscc_networkmanager_global_network" "global_network" {
  count = var.create_global_network ? 1 : 0
  tags = [{
    key   = "Name"
    value = var.global_network_name
  }]
}

resource awscc_networkmanager_core_network "core_network"{
    count = var.create_global_network && var.create_core_network ? 1 : 0
    description =  var.core_network_description
    global_network_id = awscc_networkmanager_global_network.global_network[0].id
    policy_document   = var.policy_document
}
