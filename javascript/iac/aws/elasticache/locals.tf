locals {
  engine_major_version            = join(".", slice(split(".", var.engine_version), 0, 2))
  default_parameter_group_name    = "default.${var.engine}${local.engine_major_version}.cluster.on"
  max_replication_group_id_length = 20
  replication_group_id_length = min(
    length(var.deploy_name),
    local.max_replication_group_id_length,
  )

  // Remove hyphens from the end of the replication group id since the ID can't end with a hyphen
  search_string                    = "/-$/"
  replication_group_id_with_hyphen = substr(var.deploy_name, 0, local.replication_group_id_length)
  replication_group_id = replace(
    local.replication_group_id_with_hyphen,
    local.search_string,
    "",
  )
}

