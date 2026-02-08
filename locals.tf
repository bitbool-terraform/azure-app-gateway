locals {

letsencrypt_validator_http_settings_name = "letsencrypt-validator"

app_gateway_name = lookup(var.app_gw,"fullname",null) != null ? var.app_gw.fullname: format("%s-%s",var.app_gw.resource_group,var.default_name)

public_ip_name = lookup(var.app_gw,"public_ip_name",null) != null ? var.app_gw.public_ip_name : format("%s-PIP01",upper(local.app_gateway_name))

gateway_tags  = lookup(var.app_gw,"tags",{})

backend_address_pools = var.app_gw.backend_targets

mi_id = lookup(var.app_gw,"custom_mi",null) == null ? azurerm_user_assigned_identity.gateway_identity[0].id : data.azurerm_user_assigned_identity.gateway_identity[0].id

sku_name = lookup(var.app_gw,"sku_name",var.default_sku_name)
sku_capacity = lookup(var.app_gw,"sku_capacity",var.default_sku_capacity)

frontend_ip_name = lookup(var.app_gw,"frontend_ip_name",null) != null ? var.app_gw.frontend_ip_name : var.default_frontend_ip_name

gateway_ip_name = lookup(var.app_gw,"gateway_ip_name",null) != null ? var.app_gw.gateway_ip_name : var.default_gateway_ip_name

ssl_profiles = lookup(var.app_gw,"ssl_profiles",var.default_ssl_profiles)

zones = lookup(var.app_gw,"zones",var.default_zones)
pip_zones = lookup(var.app_gw,"pip_zones",var.default_pip_zones)

letsencrypt_backend_target = lookup(var.app_gw,"letsencrypt_backend_target",null)


distinct_hostnames = distinct(flatten([
    for lK,lV in var.app_gw.listeners : lV.hostnames
  ]))

http_listeners = {
  for lK,lV in var.app_gw.listeners: lK => {
    hostnames       = lV.hostnames
    port            = format("port_%s",lookup(lV,"port",lookup(lV,"protocol","Https") == "Http" ? 80 : 443 ))
    protocol        = lookup(lV,"protocol","Https")
    ssl_certificate_name = lookup(lV,"protocol","Https") == "Http" ? null : local.ssl_certificates[lK].name
  }
}

frontend_port_numbers = distinct(flatten([
    for lK,lV in var.app_gw.listeners : lV.port
  ]))

waf_configuration = merge(var.default_waf_configuration,lookup(var.app_gw,"waf_configuration",{}))

enable_http2 = lookup(var.app_gw,"enable_http2",var.default_enable_http2)

alerts = merge(var.default_alerts,lookup(var.app_gw,"alerts",{}))

logging = merge(var.default_logging,lookup(var.app_gw,"logging",{}))

alerts_tags = lookup(var.app_gw,"alerts_tags",null)
sa_tags = lookup(var.app_gw,"sa_tags",null)

ssl_certificates = var.app_gw.certificates

letsencrypt_backend_http_setting = local.letsencrypt_backend_target != null ? {
    "${local.letsencrypt_validator_http_settings_name}" = {
        port                    = try(local.letsencrypt_backend_target.letsencrypt.port,null)
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
  for btK,btV in local.backend_address_pools: [
    for httpSettingK,httpSettingV in lookup(btV,"http_settings",{ "main" = {} }): {
      "${format("%s_%s",btK,httpSettingK)}" = merge(var.default_backend_settings,httpSettingV)
    }
  ]
])...)

url_path_maps = {
  for ruleK,ruleV in var.app_gw.listeners: ruleK => {
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