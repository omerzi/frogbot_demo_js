
resource "kubernetes_cluster_role_binding" "sdm-ro-role" {
  metadata {
    name = "sdm-ro-role"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "view"
  }
  subject {
    kind      = "Group"
    name      = "sdm-ro-role"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role_binding" "sdm-admin-role" {
  metadata {
    name = "sdm-admin-role"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind      = "Group"
    name      = "sdm-admin-role"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role" "sdm-ro-role" {
  metadata {
    name = "sdm-ro-role"
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "sdm-roles" {
  for_each = toset(var.rbac_admin_roles)
  metadata {
    name = "${each.value}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind      = "Group"
    name      = "${each.value}"
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_cluster_role" "sdm-ro-roles" {

  metadata {
    labels = {
     "rbac.authorization.k8s.io/aggregate-to-view" =  "true"
    }
    name = "jfrog-custom-view-only-role"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "sdm-ro-roles" {
  for_each = toset(var.rbac_readonly_roles)
  metadata {
    name = "${each.value}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "view"
  }
  subject {
    kind      = "Group"
    name = "${each.value}"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role" "ba-team-port-forwarding" { // will be use by ba-team for port forwarding in  jfapps clusters
  for_each = toset(var.jfapps_ba_ns)
  metadata {
    name = "ba-team-ro"
    namespace = "${each.value}"
  }
  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["get", "list", "create"]
  }

}
resource "kubernetes_role_binding" "ba-team-port-forwarding" { // will be use by ba-team for port forwarding in  jfapps clusters
  for_each = toset(var.jfapps_ba_ns)
  metadata {
    name = "ba-team-ro"
    namespace = "${each.value}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "ba-team-ro"
  }
  subject {
    kind      = "Group"
    name = "ba-team-ro"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role" "allow-exec" { // will allow pod exec
  for_each = toset(var.rbac_pod_exec_roles)
 metadata {
    name = "${each.value}"
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }

}
resource "kubernetes_cluster_role_binding" "allow-exec" { // will allow pod exec
  for_each = toset(var.rbac_pod_exec_roles)
  metadata {
    name = "${each.value}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "${each.value}"
  }
  subject {
    kind      = "Group"
    name = "${each.value}"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role" "admin_access_namespace" { // will allow full access on the specifcy namespace
  for_each = (var.rbac_admin_namespaces)
 metadata {
    namespace = "${each.value.namespace}"
    name = "${each.value.sdm_role}"
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["*"]
    verbs      = ["*"]
  }

}
resource "kubernetes_role_binding" "admin_access_namespace" { // will allow full access on the specifcy namespace
  for_each = var.rbac_admin_namespaces
  metadata {
    name = "${each.value.sdm_role}"
    namespace = "${each.value.namespace}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "${each.value.sdm_role}"
  }
  subject {
    kind      = "Group"
    name =  "${each.value.sdm_role}"
    namespace =  "${each.value.namespace}"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role_binding" "stackstorm_svc" { // will allow stackstorm_svc access
  count = var.create_stackstorm_rbac ? 1 : 0
  metadata {
    name = "stackstorm_svc"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "stackstorm_svc"
  }
  subject {
    kind      = "Group"
    name = "stackstorm_svc"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role" "stackstorm_svc" {
  count = var.create_stackstorm_rbac ? 1 : 0
  metadata {
    name = "stackstorm_svc"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "watch", "list", "create", "delete", "update"]
  }
  rule {
    api_groups = ["apps", "extentions"]
    resources  = ["deployments", "deployments/scale", "deployments/status", "deployments/rollback", "statefulsets", "statefulsets/scale"]
    verbs      = ["get", "watch", "list", "create", "delete", "update"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "statefulsets/scale"]
    verbs      = ["get", "watch", "list", "create", "delete", "update", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "namespaces/status", "secrets", "configmaps", "persistentvolumeclaims", "persistentvolumes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "watch", "list", "update"]
  }
  rule {
    api_groups = ["networking.k8s.io", "extensions"]
    resources  = ["ingresses", "ingresses/status"]
    verbs      = ["get", "watch", "list", "patch", "update"]
  }
}

resource "kubernetes_cluster_role" "rnd-all" {
  for_each = toset(var.rbac_rnd_roles)
  metadata {
     name = "${each.value}"
  }
    rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log","pods/portforward"]
    verbs      = ["get", "watch", "list" , "delete", "update"]
  }
    rule {
    api_groups = [""]
    resources  = ["pods/exec","pods/portforward"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets", "configmaps"]
    verbs      = ["get", "list", "watch","update","patch"]
  }
  rule {
    api_groups = ["apps", "extentions"]
    resources  = ["deployments", "deployments/scale", "deployments/status", "deployments/rollback", "statefulsets", "statefulsets/scale"]
    verbs      = ["get", "watch", "list", "update", "patch"]
  }
}
resource "kubernetes_cluster_role_binding" "rnd-all" {
  for_each = toset(var.rbac_rnd_roles)
  metadata {
    name = "${each.value}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "${each.value}"
  }
  subject {
    kind      = "Group"
    name = "${each.value}"
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_cluster_role" "cronjobs_permissions" {
  for_each = toset(var.rbac_cronjobs_roles)
  metadata {
     name = "${each.value}"
  }
    rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
    rule {
    api_groups = ["batch"]
    resources  = ["cronjobs"]
    verbs      = ["list", "watch", "get","update", "patch"]
  }
    rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["list", "watch", "get","update", "patch","create","delete"]
  }
  
}
resource "kubernetes_cluster_role_binding" "cronjobs_permissions" {
  for_each = toset(var.rbac_cronjobs_roles)
  metadata {
    name = "${each.value}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "${each.value}"
  }
  subject {
    kind      = "Group"
    name = "${each.value}"
    api_group = "rbac.authorization.k8s.io"
  }
}
