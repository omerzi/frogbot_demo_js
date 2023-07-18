########################### SERVER ##############################################

resource "azuread_application" "server" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  display_name   = lookup(var.aks_map.override, "cluster_name", "${var.deploy_name}-${var.region}")
  reply_urls    = ["http://k8s_server"]
  type          = "webapp/api"

  # this is important, as stated by the documentation
  group_membership_claims = "All"

  required_resource_access {
    # Windows Azure Active Directory API
    resource_app_id = "00000002-0000-0000-c000-000000000000"

    resource_access {
      # DELEGATED PERMISSIONS: "Sign in and read user profile":
      # 311a71cc-e848-46a1-bdf8-97ff7156d8e6
      id   = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
      type = "Scope"
    }
  }

  required_resource_access {
    # MicrosoftGraph API
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    # APPLICATION PERMISSIONS: "Read directory data":
    # 7ab1d382-f21e-4acd-a863-ba3e13f7da61
    resource_access {
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
      type = "Role"
    }

    # DELEGATED PERMISSIONS: "Sign in and read user profile":
    # e1fe6dd8-ba31-4d61-89e7-88639da4683d
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }

    # DELEGATED PERMISSIONS: "Read directory data":
    # 06da0dbc-49e2-44d2-8312-53f166ab848a
    resource_access {
      id   = "06da0dbc-49e2-44d2-8312-53f166ab848a"
      type = "Scope"
    }
  }
  lifecycle {
    ignore_changes = [
      display_name
    ]
  }
}

resource "azuread_service_principal" "server" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  application_id = azuread_application.server[0].application_id
}


resource "azuread_service_principal_password" "server" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  service_principal_id = azuread_service_principal.server[0].id
  value                = random_string.application_server_password[0].result
  end_date             = timeadd(timestamp(), "87600h") # 10 years

  # The end date will change at each run (terraform apply), causing a new password to
  # be set. So we ignore changes on this field in the resource lifecyle to avoid this
  # behaviour.
  # If the desired behaviour is to change the end date, then the resource must be
  # manually tainted.
  lifecycle {
    ignore_changes = [end_date]
  }
}

resource "random_string" "application_server_password" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  length  = 16
  special = true

  keepers = {
    service_principal = azuread_service_principal.server[0].id
  }
}

############################ CLIENT #############################################

resource "azuread_application" "client" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true  || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  display_name   = lookup(var.aks_map.override, "override_name", "${var.deploy_name}-${var.region}")
  reply_urls    = ["http://k8s_client"]

  # This is necessary that the client app is of type "native".
  # Only allowed since the 0.4.0 version of the azuread Terraform provider.
  type = "native"

  required_resource_access {
    # Windows Azure Active Directory API
    resource_app_id = "00000002-0000-0000-c000-000000000000"

    resource_access {
      # DELEGATED PERMISSIONS: "Sign in and read user profile":
      # 311a71cc-e848-46a1-bdf8-97ff7156d8e6
      id   = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
      type = "Scope"
    }
  }

  # This is where we allow the client app to do requets to the server app.
  required_resource_access {
    # AKS ad application server
    resource_app_id = azuread_application.server[0].application_id

    resource_access {
      # Server app Oauth2 permissions id
      id   = tolist(azuread_application.server[0].oauth2_permissions)[0].id
      type = "Scope"
    }
  }
  lifecycle {
    ignore_changes = [
      display_name
    ]
  }
}

resource "azuread_service_principal" "client" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  application_id = azuread_application.client[0].application_id
}

resource "azuread_service_principal_password" "client" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true  || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  service_principal_id = azuread_service_principal.client[0].id
  value                = random_string.application_client_password[0].result
  end_date             = timeadd(timestamp(), "87600h") # 10 years

  # Same justification as the server service principal.
  lifecycle {
    ignore_changes = [end_date]
  }
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "random_string" "application_client_password" {
  count = contains(keys(var.aks_map.override), "disable_aad_rbac") != true || contains(keys(var.aks_map.override),"enable_managed_identity") != true ? 1 : 0  
  length  = 16
  special = true

  keepers = {
    service_principal = azuread_service_principal.client[0].id
  }
}

//resource "azurerm_role_assignment" "role" {
//  scope                = "" #add your scope here (like your subscription id or the AKS resource group id
//  role_definition_name = "Network Contributor"
//  principal_id         = "${azuread_service_principal.client.id}"
//}