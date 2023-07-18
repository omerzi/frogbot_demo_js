variable "module_enabled" {
  default = true
}

variable "nat_gw_module_enabled" {
  default = false
}

variable "region" {
}

variable "deploy_name" {
}

variable "resource_group_name" {
}

variable "environment" {
}

variable "ssh_key" {
}

variable "subnet" {
}

variable "tenant_id" {
}

variable "pod_cidr" {
}

variable "service_cidr" {
}

variable "dns_service_ip" {
}

variable "docker_bridge_cidr" {
}

variable "ssh_proxy_ip" {
  type = list
}

variable "aks_map" {
}

variable "enable_auto_scaling" {
}
# k8s nat gw with public ip association variables
variable "ip_version" {
  default = "IPv4"
}
variable "k8s_public_ip_ids" {
}
variable "k8s_nat_public_ips_count" {
}
variable "log_analytics_workspace_id" {
  default = ""
}
variable "rbac_admin_roles"{
  default = []
}
variable "rbac_readonly_roles"{
  default = []
}

variable "narcissus_domain_short" {
  type = string
}

variable "cloud_subscription" {
  type = string
}

variable "enable_tags" {
  default = false
}
variable "zones" {
  default = ["1","2","3"]
}
variable "create_stackstorm_rbac"{
  default = true
}