data "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_certificate" "key_vault_certificate" {
  for_each = local.ssl_certificates
 
  name                = each.value
  key_vault_id = data.azurerm_key_vault.key_vault.id
}



resource "azurerm_public_ip" "gateway_pip" {
  name                = local.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  zones               = var.pip_zones
  tags                = local.gateway_tags
}


resource "azurerm_user_assigned_identity" "gateway_identity" {
  count = var.app_gw_custom_mi == "" ? 1 : 0
  name                = format("%s-mi",local.app_gateway_name)
  resource_group_name = var.resource_group_name
  location            = var.location
}

data "azurerm_user_assigned_identity" "gateway_identity" {
  count = var.app_gw_custom_mi != "" ? 1 : 0    
  name                = var.app_gw_custom_mi
  resource_group_name = var.resource_group_name
}

resource "azurerm_application_gateway" "gateway" {
  name                = local.app_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.gateway_tags
  zones               = var.zones
  enable_http2        = var.enable_http2

  firewall_policy_id    = var.firewall_policy_id

  sku {
    name     = var.sku_name
    tier     = var.sku_name
    capacity = var.sku_capacity
  }

  dynamic "autoscale_configuration" {
    for_each = var.autoscale_configuration == true ? [""] : []

    content {
      min_capacity     = var.autoscale_min_capacity
      max_capacity     = var.autoscale_max_capacity
    }
  }

  identity {
      type         = "UserAssigned"
      identity_ids = [local.mi_id]
  }

  gateway_ip_configuration {
    name      = var.gateway_ip_name
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = var.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.gateway_pip.id
  }


  dynamic "backend_address_pool" {
    for_each = merge(local.backend_address_pools,var.letsencrypt_backend_target)

    content {
      name         = backend_address_pool.key
      fqdns        = lookup(backend_address_pool.value,"fqdns",null)
      ip_addresses = lookup(backend_address_pool.value,"ip_addresses",null)
    }
  }

  dynamic "frontend_port" {
    for_each = { for k in local.frontend_port_numbers: k => k }

    content {
      name = format("port_%s",frontend_port.key)
      port = frontend_port.key
    }
  }

  dynamic "ssl_certificate" {
    for_each = local.ssl_certificates

    content {
      name                = ssl_certificate.value
      key_vault_secret_id = data.azurerm_key_vault_certificate.key_vault_certificate[ssl_certificate.key].versionless_secret_id #Versionless required for cert rotation
    }
  }

  dynamic "http_listener" { # 2 listeners / hostname
    for_each = local.http_listeners

    content {
      name                           = http_listener.key
      frontend_ip_configuration_name = var.frontend_ip_name
      frontend_port_name             = http_listener.value.port
      protocol                       = http_listener.value.protocol
      host_names                     = http_listener.value.hostnames
      ssl_certificate_name           = http_listener.value.ssl_certificate_name
    }
  }

  dynamic "probe" { #/app
    for_each = merge(local.backend_http_settings,local.letsencrypt_backend_http_setting)

    content {
      name                                      = probe.key
      host                                      = try(probe.value.host_name,null)
      protocol                                  = probe.value.protocol
      path                                      = probe.value.probe_path
      interval                                  = probe.value.probe_interval
      timeout                                   = probe.value.probe_timeout
      unhealthy_threshold                       = probe.value.probe_unhealthy_threshold
      pick_host_name_from_backend_http_settings = lookup(probe.value,"host_name",false)? false : true
      
      match {
        status_code = probe.value.status_code
      }
    }
  }

    dynamic "backend_http_settings" { #/app
      for_each = merge(local.backend_http_settings,local.letsencrypt_backend_http_setting)

      content {
          name                                = backend_http_settings.key
          port                                = backend_http_settings.value.port
          protocol                            = backend_http_settings.value.protocol
          cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
          request_timeout                     = backend_http_settings.value.request_timeout
          host_name                           = try(backend_http_settings.value.host_name,null)
          pick_host_name_from_backend_address = lookup(backend_http_settings.value,"host_name",false)? false : true
          probe_name                          = backend_http_settings.key
      }
    }


    dynamic "request_routing_rule" {#/listener
      for_each = local.http_listeners

      content {
          name                       = request_routing_rule.key
          rule_type                  = "PathBasedRouting"
          priority                   = 10 * (index(keys(local.http_listeners), request_routing_rule.key))+100
          http_listener_name         = request_routing_rule.key
          url_path_map_name          = request_routing_rule.key
      }
    }

    dynamic "url_path_map" { 
        for_each = local.url_path_maps

        content {
          name                                = url_path_map.key
          default_redirect_configuration_name = url_path_map.value.default_redirect_configuration_name
          default_backend_address_pool_name   = url_path_map.value.default_backend_address_pool_name
          default_backend_http_settings_name  = url_path_map.value.default_backend_http_settings_name
          default_rewrite_rule_set_name       = url_path_map.value.default_rewrite_rule_set_name

          dynamic "path_rule" {
              for_each = url_path_map.value.path_rules

              content {
                name                       = path_rule.key
                paths                      = path_rule.value.paths
                redirect_configuration_name = path_rule.value.redirect_configuration_name
                backend_address_pool_name  = path_rule.value.backend_address_pool_name
                backend_http_settings_name = path_rule.value.backend_http_settings_name
                rewrite_rule_set_name      = lookup(path_rule.value,"rewrite_rule_set_name",null)
              }
          }
        }
    }

    # dynamic "url_path_map" { #/listener
    #     for_each = local.url_path_maps_http

    #     content {
    #     name                                = url_path_map.key
    #     default_redirect_configuration_name = url_path_map.key

    #     dynamic "path_rule" {
    #           for_each = url_path_map.value.path_rules

    #         content {
    #           name                        = path_rule.key
    #           paths                       = path_rule.value.paths
    #           redirect_configuration_name = lookup(path_rule.value,"redirect_configuration_name",null)
    #           backend_address_pool_name   = lookup(path_rule.value,"backend_address_pool_name",null)
    #           backend_http_settings_name  = lookup(path_rule.value,"backend_http_settings_name",null)
    #           rewrite_rule_set_name      = lookup(path_rule.value,"rewrite_rule_set_name",null)
    #         }
    #     }
    #     }
    # }

    dynamic "redirect_configuration" { # /http-listener
      for_each = var.redirections

      content {
          name                 = redirect_configuration.key
          redirect_type        = lookup(redirect_configuration.value,"redirect_type","Permanent")
          include_path         = lookup(redirect_configuration.value,"include_path",true)
          include_query_string = lookup(redirect_configuration.value,"include_query_string",true)
          target_listener_name = try(redirect_configuration.value.target_listener_name,null)
          target_url           = try(redirect_configuration.value.target_url,null)
      }
    }

    dynamic "ssl_profile" {
      for_each = var.ssl_profiles 

      content {
        name                                 = ssl_profile.key
        trusted_client_certificate_names     = lookup(ssl_profile.value,"trusted_client_certificate_names",null)
        verify_client_cert_issuer_dn         = lookup(ssl_profile.value,"verify_client_cert_issuer_dn",false)
        verify_client_certificate_revocation = lookup(ssl_profile.value,"verify_client_certificate_revocation",null)
        ssl_policy {
          policy_type  = "Predefined"
          policy_name  = ssl_profile.value.policy_name
        }
      } 
    }

    dynamic "rewrite_rule_set" {
      for_each = var.security_headers_enabled ? var.security_headers : {}

      content {
        name = format("security_headers_%s",rewrite_rule_set.key)

        rewrite_rule {
          name          = "add-headers"
          rule_sequence = 1

          dynamic "response_header_configuration" {
            for_each = rewrite_rule_set.value

            content {
              header_name  = response_header_configuration.key
              header_value = response_header_configuration.value
            }
          }
        }
      }
    }
}


data "azurerm_network_interface" "nic" {
  for_each =  { for k,v in merge(local.backend_address_pools,var.letsencrypt_backend_target): k=>v if lookup(v,"nic","") != "" }

  name                = each.value.nic
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic_association" {

  for_each =  { for k,v in merge(local.backend_address_pools,var.letsencrypt_backend_target): k=>v if lookup(v,"nic","") != "" }

  network_interface_id    = data.azurerm_network_interface.nic[each.key].id
  ip_configuration_name   = data.azurerm_network_interface.nic[each.key].ip_configuration[0].name
  backend_address_pool_id = local.agw_backend_pool_ids[each.key]
}

