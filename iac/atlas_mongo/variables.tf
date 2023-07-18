variable "mongodb_atlas_org_id" {
  default = "5ee60361e397bf0a00d27f69"

}

variable "is_collect_database_specifics_statistics_enabled" {
  default = true

}

variable "is_data_explorer_enabled" {
  default = true

}

variable "is_performance_advisor_enabled" {
  default = true

}

variable "is_realtime_performance_panel_enabled" {
  default = true

}

variable "is_schema_advisor_enabled" {
  default = true

}

variable "create_atlas_project" {
  default = false
}

variable "project_id" {
  default = ""
}

variable "project_name" {
  default = ""
}

variable "provider_name" {
  default = "AWS"
}

variable "disk_size_gb" {
  default = ""
}

variable "cloud_backup" {
  default = true
}

variable "pit_enabled" {
  default = true
}

variable "provider_instance_size_name" {
  default = ""
}

variable "mongo_db_major_version" {
  default = ""
}

variable "auto_scaling_disk_gb_enabled" {
  default = true
}

variable "replication_num_shards" {
  default = 1
}


variable "mongodb_atlas_database_username" {
  default = "mongo_admin"
}

variable "auth_database_name" {
  default = "admin"
}

variable "atls_user_role_name" {
  default = "atlasAdmin"
}

variable "atls_user_database_name" {
  default = "admin"
}

variable "cluster_type" {
  default = "REPLICASET"
}

variable "cluster_name" {
  default = ""
}
variable "length_distinct_outbound_ips" {
  default = ""
}

variable "distinct_outbound_ips" {
  default = []
}

variable "regions_config" {
  default = ""
}

variable "mongo_dbs_map" {
  default = {}
}

variable "user_db" {
  default = []
}

variable "zone_name" {
  default = ""
}

variable "with_default_alerts_settings" {
  default = "true"
}


variable "teams" {
  default = {}
  
}
