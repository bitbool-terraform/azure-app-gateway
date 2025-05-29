locals {

app_gateway_name = var.app_gateway_fullname != "" ? var.app_gateway_fullname: format("%s-%s",var.resource_group_name,var.name)

name_prefix = var.project

gateway_tags  = var.tags != null ? var.tags : {
        project   = var.project
}

backend_address_pools = var.backend_targets


mi_id = var.app_gw_custom_mi == "" ? azurerm_user_assigned_identity.gateway_identity[0].id : data.azurerm_user_assigned_identity.gateway_identity[0].id



distinct_hostnames = distinct([
    for entry in var.routing_rules : entry.hostname
  ])


  rules_grouped_by_hostname = {
    for host in local.distinct_hostnames : host => {
      for name, obj in var.routing_rules : name => {
        backend_target = obj.backend_target
        backend_port   = obj.backend_port
        path           = lookup(obj,"path","/*")

      } if obj.hostname == host
    }
  }


http_listeners = merge(
  flatten([
    [
      for k, v in local.rules_grouped_by_hostname : {
        "${replace(k, ".", "-")}-http" = {
          hostname        = k
          port            = "port_80"
          protocol        = "Http"
          use_letsencrypt = local.ssl_certificates[k]==replace(k, ".", "-") ? true : false
        }
      }
    ],
    [
      for k, v in local.rules_grouped_by_hostname : {
        "${replace(k, ".", "-")}-ssl" = {
          hostname             = k
          port                 = "port_443"
          protocol             = "Https"
          ssl_certificate_name = local.ssl_certificates[k]
        }
      }
    ]
  ])...
)


ssl_certificates = {
  for host, _ in local.rules_grouped_by_hostname : host => (
    can(
      [for k, cert in var.certificates_custom : cert.name if cert.hostname == host][0]
    )
    ? [for k, cert in var.certificates_custom : cert.name if cert.hostname == host][0]
    : replace(host, ".", "-")
  )
}


letsencrypt_backend_http_setting = var.letencrypt_backend_target != null ? {
    "letsencrypt-validator" = {
        port                    = var.letencrypt_backend_port
        protocol                = "Http"
        cookie_based_affinity   = "Disabled"
        request_timeout         = var.request_timeout
        pick_host_name_from_backend_address = true
        pick_host_name_from_backend_http_settings = true
    }


} : {}


backend_http_settings = merge({
for k, v in var.routing_rules :
    k => {
        port                    = v.backend_port
        protocol                = "Http"
        cookie_based_affinity   = lookup(v,"cookie_based_affinity",var.cookie_based_affinity)
        request_timeout         = lookup(v,"request_timeout",var.request_timeout)
        hostname                = v.hostname
        pick_host_name_from_backend_address = lookup(v,"pick_host_name_from_backend_address",false)
    }
},local.letsencrypt_backend_http_setting)


url_path_maps = merge(local.url_path_maps_ssl,local.url_path_maps_http)


url_path_maps_http = {
  for lstK, lstV in local.http_listeners: 
      lstK => {
        default_redirect_configuration_name = lstK

        path_rules = merge({
            for appK, appV in local.rules_grouped_by_hostname[lstV.hostname]:
                "${lstK}-${appK}-redirect" => {
                    paths = [appV.path]
                    redirect_configuration_name = lstK
                }},
                lstV.use_letsencrypt ? {
                "${lstK}-letsencrypt" = {
                    paths = ["/.well-known/*"]
                    backend_address_pool_name = var.letencrypt_backend_target
                    backend_http_settings_name =  format("%s-letsencrypt-validator",local.name_prefix)
                    }
                }: {}
                )
                
        
      } if lookup(lstV,"protocol","") == "Http"
}


url_path_maps_ssl = {
  for lstK, lstV in local.http_listeners: 
      lstK => {
        default_backend_address_pool_name = one([for rule in values(local.rules_grouped_by_hostname[lstV.hostname]) : rule.backend_target if rule.path == "/*" ])
        default_backend_http_settings_name = format("%s-%s",local.name_prefix,one([for k,v in local.rules_grouped_by_hostname[lstV.hostname] : k if v.path == "/*" ]))

        path_rules = {
            for appK, appV in local.rules_grouped_by_hostname[lstV.hostname]:
                "${lstK}-${appK}" => {
                    paths = [appV.path]
                    backend_address_pool_name = appV.backend_target
                    backend_http_settings_name = format("%s-%s",local.name_prefix,appK)
                }
        }
      } if lookup(lstV,"protocol","") == "Https"
}


redirections = {
      for lstK, lstV in local.http_listeners: 
      lstK => {
        redirect_type = "Permanent"
        target_listener_name = replace(lstK, "-http", "-ssl")
        include_path = true
        include_query_string = true
        } if lookup(lstV,"protocol","") == "Http"
      }


agw_backend_pool_ids = {
    for p in azurerm_application_gateway.gateway.backend_address_pool :
        p.name => p.id
  }

}