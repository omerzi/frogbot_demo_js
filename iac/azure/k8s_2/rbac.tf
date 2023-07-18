
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
  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
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
  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
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
  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
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
  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
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
  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
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