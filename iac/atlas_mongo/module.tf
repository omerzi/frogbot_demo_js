resource "mongodbatlas_project" "atlas_project" {
  count  = var.create_atlas_project ? 1 : 0
  name   = var.project_name
  org_id = var.mongodb_atlas_org_id

  is_collect_database_specifics_statistics_enabled = var.is_collect_database_specifics_statistics_enabled
  is_data_explorer_enabled                         = var.is_data_explorer_enabled
  is_performance_advisor_enabled                   = var.is_performance_advisor_enabled
  is_realtime_performance_panel_enabled            = var.is_realtime_performance_panel_enabled
  is_schema_advisor_enabled                        = var.is_schema_advisor_enabled
  with_default_alerts_settings                     = var.with_default_alerts_settings

 dynamic "teams" {
    for_each = length(var.teams)> 0 ? var.teams : {}
    content {
    team_id    = teams.value.team_id
    role_names = teams.value.role_names 
    }
  }

}


resource "mongodbatlas_cluster" "db_cluster" {
  for_each  = var.mongo_dbs_map
  project_id   = var.project_id != "" ? var.project_id : mongodbatlas_project.atlas_project[0].id
  name         = lookup(each.value,"cluster_name")
  cluster_type = lookup(each.value,"cluster_type","REPLICASET")

  provider_name = lookup(each.value,"provider_name","AWS") 
  disk_size_gb  = lookup(each.value,"disk_size_gb") 
  cloud_backup  = lookup(each.value,"cloud_backup",true)
  pit_enabled   = lookup(each.value,"pit_enabled",true) 
  provider_instance_size_name=lookup(each.value,"provider_instance_size_name")
  mongo_db_major_version=lookup(each.value,"mongo_db_major_version")
  auto_scaling_disk_gb_enabled=lookup(each.value,"auto_scaling_disk_gb_enabled",true)

  # options: M2/M5 atlas regions per cloud provider
  # GCP - CENTRAL_US SOUTH_AMERICA_EAST_1 WESTERN_EUROPE EASTERN_ASIA_PACIFIC NORTHEASTERN_ASIA_PACIFIC ASIA_SOUTH_1
  # AZURE - US_EAST_2 US_WEST CANADA_CENTRAL EUROPE_NORTH
  # AWS - US_EAST_1 US_WEST_2 EU_WEST_1 EU_CENTRAL_1 AP_SOUTH_1 AP_SOUTHEAST_1 AP_SOUTHEAST_2


  replication_specs {
    num_shards = var.replication_num_shards
    zone_name = var.zone_name

    dynamic regions_config {
      for_each=var.mongo_dbs_map[each.key].regions_config
      content {
      region_name     = regions_config.value["region_name"]
      electable_nodes = regions_config.value.electable_nodes
      priority        = regions_config.value.priority
      read_only_nodes = regions_config.value.read_only_nodes
      
      }
    }
  }
}

### resource for creating Atlas users###
# resource "mongodbatlas_database_user" "atlas_user" {
#   count  = length(var.user_db)
#   username           = var.user_db[count.index]["username"]
#   password           = random_password.password.result
#   project_id         = var.create_atlas_project ? mongodbatlas_project.atlas_project[0].id : var.project_id
#   auth_database_name = var.user_db[count.index]["auth_database_name"]

#   roles {
#     role_name     = var.user_db[count.index]["role_name"] 
#     database_name = var.user_db[count.index]["database_name"]
#   }

#   lifecycle {
#     ignore_changes = [
#       password
#     ]
#   }
# }

# resource "random_password" "password" {
#   length  = var.random_password_length
#   special = var.random_password_special
#   lower = var.random_password_lower
#   min_lower = var.random_password_min_lower
#   min_numeric = var.random_password_min_numeric
#   min_special = var.random_password_min_special
#   min_upper = var.random_password_min_upper
#   upper = var.random_password_upper

# }

resource "mongodbatlas_project_ip_access_list" "db_ipaddress" {
  count = var.length_distinct_outbound_ips
  project_id = var.create_atlas_project ? mongodbatlas_project.atlas_project[0].id : var.project_id
  cidr_block = lookup(var.distinct_outbound_ips[count.index],"cidr_block")
  comment    = lookup(var.distinct_outbound_ips[count.index],"comment")
}

   

