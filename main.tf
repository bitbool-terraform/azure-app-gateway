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
    for_each = local.backend_address_pools

    content {
      name         = backend_address_pool.key
      fqdns        = lookup(backend_address_pool.value,"fqdns",null)
      ip_addresses = lookup(backend_address_pool.value,"ip_addresses",null)
    }
  }

    frontend_port {
        name = "port_80"
        port = 80
    }

    frontend_port {
        name = "port_443"
        port = 443
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
      host_name                      = http_listener.value.hostname
      ssl_certificate_name           = http_listener.value.protocol == "Https" ? http_listener.value.ssl_certificate_name: null
      #host_names = 
    }
  }

  dynamic "probe" { #/app
    for_each = local.backend_http_settings

    content {
      name                                      = format("%s-%s",local.name_prefix,probe.key)
      host                                      = probe.value.host_name_override != null ? probe.value.host_name_override : lookup(probe.value,"hostname",null)
      protocol                                  = "Http"
      path                                      = "/"
      interval                                  = lookup(probe.value,"probe_interval",var.probe_interval)
      timeout                                   = lookup(probe.value,"probe_timeout",var.probe_timeout)
      unhealthy_threshold                       = lookup(probe.value,"probe_unhealthy_threshold",var.unhealthy_threshold)
      pick_host_name_from_backend_http_settings = lookup(probe.value,"pick_host_name_from_backend_http_settings",false)
      
      match {
        status_code = ["200-499"]
      }
    }
  }

    dynamic "backend_http_settings" { #/app
    for_each = local.backend_http_settings

    content {
        name                                = format("%s-%s",local.name_prefix,backend_http_settings.key)
        port                                = backend_http_settings.value.port
        protocol                            = backend_http_settings.value.protocol
        cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
        request_timeout                     = backend_http_settings.value.request_timeout
        host_name                           = backend_http_settings.value.host_name_override
        pick_host_name_from_backend_address = backend_http_settings.value.pick_host_name_from_backend_address
        probe_name                          = format("%s-%s",local.name_prefix,backend_http_settings.key)
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

    dynamic "url_path_map" { #/SSL listener
        for_each = local.url_path_maps_ssl

        content {
        name                                = url_path_map.key
        default_backend_address_pool_name   = url_path_map.value.default_backend_address_pool_name
        default_backend_http_settings_name  = url_path_map.value.default_backend_http_settings_name

        dynamic "path_rule" {
              for_each = url_path_map.value.path_rules

            content {
            name                       = path_rule.key
            paths                      = path_rule.value.paths
            backend_address_pool_name  = path_rule.value.backend_address_pool_name
            backend_http_settings_name = path_rule.value.backend_http_settings_name

            }
        }
        }
    }

    dynamic "url_path_map" { #/listener
        for_each = local.url_path_maps_http

        content {
        name                                = url_path_map.key
        default_redirect_configuration_name = url_path_map.key

        dynamic "path_rule" {
              for_each = url_path_map.value.path_rules

            content {
            name                        = path_rule.key
            paths                       = path_rule.value.paths
            redirect_configuration_name = lookup(path_rule.value,"redirect_configuration_name",null)
            backend_address_pool_name   = lookup(path_rule.value,"backend_address_pool_name",null)
            backend_http_settings_name  = lookup(path_rule.value,"backend_http_settings_name",null)

            }
        }
        }
    }

    dynamic "redirect_configuration" { # /http-listener
    for_each = local.redirections

    content {
        name                 = redirect_configuration.key
        redirect_type        = redirect_configuration.value.redirect_type
        include_path         = redirect_configuration.value.include_path
        include_query_string = redirect_configuration.value.include_query_string
        target_listener_name = redirect_configuration.value.target_listener_name
    }
    }
}


data "azurerm_network_interface" "nic" {
  for_each =  { for k,v in local.backend_address_pools: k=>v if lookup(v,"nic","") != "" }

  name                = each.value.nic
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic_association" {

    for_each =  { for k,v in local.backend_address_pools: k=>v if lookup(v,"nic","") != "" }

  network_interface_id    = data.azurerm_network_interface.nic[each.key].id
  ip_configuration_name   = data.azurerm_network_interface.nic[each.key].ip_configuration[0].name
  backend_address_pool_id = local.agw_backend_pool_ids[each.key]
}

