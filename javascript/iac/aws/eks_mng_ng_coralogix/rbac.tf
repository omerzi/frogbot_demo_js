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