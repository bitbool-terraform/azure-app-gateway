data "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_public_ip" "gateway_pip" {
  name                = format("%s-pip",local.app_gateway_name)
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
}


resource "azurerm_user_assigned_identity" "gateway_identity" {
  name                = format("%s-mi",local.app_gateway_name)
  resource_group_name = var.resource_group_name
  location            = var.location
}

# data "azurerm_key_vault_certificate" "certificate" {
#     for_each = local.ssl_certificates
#   name         = each.value
#   key_vault_id = data.azurerm_key_vault.key_vault.id
# }


resource "azurerm_application_gateway" "gateway" {
  name                = local.app_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.gateway_tags
  zones               = var.zones


  sku {
    name     = var.sku_name
    tier     = var.sku_name
    capacity = var.capacity
  }

#   dynamic "autoscale_configuration" {
#     for_each = var.autoscale_configuration != null ? [""] : []

#     content {
#       min_capacity = var.autoscale_configuration.min_capacity
#       max_capacity = var.autoscale_configuration.max_capacity
#     }
#   }

  identity {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.gateway_identity.id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-public-ip-configuration"
    public_ip_address_id = azurerm_public_ip.gateway_pip.id
  }


#   dynamic "frontend_ip_configuration" {
#     for_each = var.frontend_ip_configuration.subnet_id != null ? [""] : []

#     content {
#       name                          = "FrontendPrivateIpConfiguration"
#       subnet_id                     = var.subnet_id
#       private_ip_address_allocation = var.subnet_id != null ? "Static" : null
#       private_ip_address            = var.frontend_ip_configuration.private_ip_address
#     }
#   }

  dynamic "backend_address_pool" {
    for_each = local.backend_address_pools

    content {
      name         = backend_address_pool.key
      fqdns        = backend_address_pool.value.fqdns
      ip_addresses = backend_address_pool.value.ip_addresses
    }
  }


  dynamic "frontend_port" {
    for_each = local.http_listeners

    content {
      name = frontend_port.key
      port = frontend_port.value.port
    }
  }

#   dynamic "ssl_certificate" {
#     for_each = local.ssl_certificates

#     content {
#       name                = ssl_certificate.value
#       key_vault_secret_id = azurerm_key_vault_certificate.key_vault_certificate[ssl_certificate.key].secret_id
#     }
#   }

  dynamic "http_listener" { # 2 listeners / hostname
    for_each = local.http_listeners

    content {
      name                           = http_listener.key
      frontend_ip_configuration_name = "frontend-public-ip-configuration"
      frontend_port_name             = http_listener.value.port
      protocol                       = http_listener.value.protocol
      host_name                      = http_listener.value.hostname

      #host_names = 
      #ssl_certificate_name

        # dynamic "ssl_certificate_name" {
        # for_each = http_listener.value.protocol == "Https" ? [1] : []
        # content {
        #     ssl_certificate_name = http_listener.value.ssl_certificate_name
        # }
        # }
    }
  }

#   dynamic "probe" {
#     for_each = var.probes

#     content {
#       name                                      = probe.value.name
#       host                                      = probe.value.host
#       protocol                                  = probe.value.protocol
#       path                                      = probe.value.path
#       interval                                  = probe.value.interval
#       timeout                                   = probe.value.timeout
#       unhealthy_threshold                       = probe.value.unhealthy_threshold
#       pick_host_name_from_backend_http_settings = probe.value.host == null ? true : null
#     }
#   }

    dynamic "backend_http_settings" { #/app
    for_each = local.backend_http_settings

    content {
        name                                = format("%s-%s",local.name_prefix,backend_http_settings.key)
        port                                = backend_http_settings.value.port
        protocol                            = backend_http_settings.value.protocol
        cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
        request_timeout                     = backend_http_settings.value.request_timeout
        host_name                           = backend_http_settings.value.hostname
        #pick_host_name_from_backend_address = backend_http_settings.value.hostname == null ? true : null
    #   probe_name                          = backend_http_settings.value.probe_name
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


    dynamic "url_path_map" { #/listener
        for_each = local.http_listeners

        content {
        name                                = url_path_map.key
        default_backend_address_pool_name   = one([for rule in values(local.rules_grouped_by_hostname[url_path_map.value.hostname]) : rule.backend_target if rule.path == "/" ])

        default_backend_http_settings_name  = format("%s-%s",local.name_prefix,one([for k,v in local.rules_grouped_by_hostname[url_path_map.value.hostname] : k if v.path == "/" ]))
        # default_redirect_configuration_name = 

        dynamic "path_rule" {
              for_each = local.rules_grouped_by_hostname[url_path_map.value.hostname]

            content {
            name                       = format("%s-%s",url_path_map.key,path_rule.key)
            paths                      = [path_rule.value.path]
            backend_address_pool_name  = path_rule.value.backend_target
            backend_http_settings_name = format("%s-%s",local.name_prefix,path_rule.key)
            # redirect_configuration_name = 

            }
        }
        }
    }

    # dynamic "redirect_configuration" {
    # for_each = var.redirect_configuration != null ? var.redirect_configuration : {}

    # content {
    #     name                 = redirect_configuration.value.name
    #     redirect_type        = redirect_configuration.value.redirect_type
    #     include_path         = redirect_configuration.value.include_path
    #     include_query_string = redirect_configuration.value.include_query_string
    #     target_listener_name = redirect_configuration.value.target_listener_name
    #     target_url           = redirect_configuration.value.target_url
    # }
    # }





}