# data "azurerm_key_vault" "key_vault" {
#   name                = var.key_vault_name
#   resource_group_name = var.resource_group_name
# }



# resource "azurerm_user_assigned_identity" "gateway_identity" {
#   name                = format("%s-mi",local.app_gateway_name)
#   resource_group_name = var.resource_group_name
#   location            = var.location
# }


# resource "azurerm_key_vault_certificate" "key_vault_certificate" {
#   for_each = { for k,v in local.ssl_certificates: k=>v if var.initialize_certificates }

#   name         = each.value
#   key_vault_id = data.azurerm_key_vault.key_vault.id

#   certificate_policy {
#     issuer_parameters {
#       name = "Self"
#     }

#     key_properties {
#       exportable = true
#       key_size   = 2048
#       key_type   = "RSA"
#       reuse_key  = true
#     }

#     lifetime_action {
#       action {
#         action_type = "AutoRenew"
#       }

#       trigger {
#         days_before_expiry = 365
#       }
#     }

#     secret_properties {
#       content_type = "application/x-pkcs12"
#     }

#     x509_certificate_properties {
#       # Server Authentication = 1.3.6.1.5.5.7.3.1
#       # Client Authentication = 1.3.6.1.5.5.7.3.2
#       extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

#       key_usage = [
#         "cRLSign",
#         "dataEncipherment",
#         "digitalSignature",
#         "keyAgreement",
#         "keyCertSign",
#         "keyEncipherment",
#       ]

#       subject_alternative_names {
#         dns_names = [each.key]
#       }

#       subject            = "CN=${each.key}"
#       validity_in_months = 12
#     }
#   }
# }