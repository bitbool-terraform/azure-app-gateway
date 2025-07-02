locals {

letsencrypt_validator_http_settings_name = "letsencrypt-validator"

app_gateway_name = var.app_gateway_fullname != "" ? var.app_gateway_fullname: format("%s-%s",var.resource_group_name,var.name)

public_ip_name = var.public_ip_name != "" ? var.public_ip_name : format("%s-PIP01",upper(local.app_gateway_name))

gateway_tags  = var.tags

backend_address_pools = var.backend_targets


mi_id = var.app_gw_custom_mi == "" ? azurerm_user_assigned_identity.gateway_identity[0].id : data.azurerm_user_assigned_identity.gateway_identity[0].id


 
distinct_hostnames = distinct(flatten([
    for lK,lV in var.listeners : lV.hostnames
  ]))


http_listeners = {
  for lK,lV in var.listeners: lK => {
    hostnames       = lV.hostnames
    port            = format("port_%s",lookup(lV,"port",lookup(lV,"protocol","Https") == "Http" ? 80 : 443 ))
    protocol        = lookup(lV,"protocol","Https")
    ssl_certificate_name = lookup(lV,"protocol","Https") == "Http" ? null : local.ssl_certificates[lV.hostnames[0]]
  }
}

frontend_port_numbers = distinct(flatten([
    for lK,lV in var.listeners : lV.port
  ]))

ssl_certificates = {
  #TODO use local.distinct_hostnames  
  for hostname in local.distinct_hostnames : hostname => (
    can(
      [for k, cert in var.certificates_custom : cert.name if cert.hostname == hostname][0]
    )
    ? [for k, cert in var.certificates_custom : cert.name if cert.hostname == hostname][0]
    : replace(hostname, ".", "-")
  )
}


letsencrypt_backend_http_setting = var.letsencrypt_backend_target != null ? {
    "${local.letsencrypt_validator_http_settings_name}" = {
        port                    = try(var.letsencrypt_backend_target.letsencrypt.port,null)
        protocol                = "Http"
        cookie_based_affinity   = "Disabled"
        request_timeout         = 60
        pick_host_name_from_backend_address = true
        pick_host_name_from_backend_http_settings = true
        host_name_override      = null
        probe_path              = "/"
        probe_interval          = 60
        probe_timeout           = 5
        probe_unhealthy_threshold = 5
        status_code             = [200]
    }


} : {}


backend_http_settings = merge(flatten([
  for btK,btV in var.backend_targets: [
    for httpSettingK,httpSettingV in lookup(btV,"http_settings",{ "main" = {} }): {
      "${format("%s_%s",btK,httpSettingK)}" = merge(var.default_backend_settings,httpSettingV)
    }
  ]
])...)

url_path_maps = {
  for ruleK,ruleV in var.listeners: ruleK => {
    default_redirect_configuration_name = lookup(ruleV,"redirect_to",null)
    default_backend_address_pool_name = try(lookup(ruleV,"redirect_to",false) ? null : ruleV.backend_target,null)
    default_backend_http_settings_name = try(lookup(ruleV,"redirect_to",false) ? null : format("%s_%s",ruleV.backend_target,lookup(ruleV,"http_settings","main")),null)
    default_rewrite_rule_set_name = lookup(ruleV,"rewrite_rule_set_name",null)        

    path_rules = merge({
        for pathRuleK,pathRuleV in lookup(ruleV,"path_rules",{"root" = { "paths" =["/*"]}}): pathRuleK => {
          paths = pathRuleV.paths
          redirect_configuration_name = lookup(pathRuleV,"redirect_to",lookup(ruleV,"redirect_to",null))
          backend_address_pool_name = lookup(pathRuleV,"redirect_to",lookup(ruleV,"redirect_to",null)) != null ? null : lookup(pathRuleV,"backend_target",lookup(ruleV,"backend_target",null))
          backend_http_settings_name = lookup(pathRuleV,"redirect_to",lookup(ruleV,"redirect_to",null)) != null ? null : format("%s_%s",lookup(pathRuleV,"backend_target",lookup(ruleV,"backend_target",null)),lookup(pathRuleV,"http_settings",lookup(ruleV,"http_settings","main")))
          rewrite_rule_set_name = lookup(pathRuleV,"rewrite_rule_set_name",lookup(ruleV,"rewrite_rule_set_name",null))
        }
      },
      lookup(ruleV,"use_letsencrypt",false) ? {
        "${ruleK}-letsencrypt" = {
          paths = ["/.well-known/*"]
          redirect_configuration_name = null
          backend_address_pool_name = "letsencrypt"
          backend_http_settings_name =  local.letsencrypt_validator_http_settings_name
          rewrite_rule_set_name = null
        }
      }: {}
    )
  }
}

agw_backend_pool_ids = {
    for p in azurerm_application_gateway.gateway.backend_address_pool :
        p.name => p.id
  }

}