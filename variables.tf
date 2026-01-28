variable "name" { 
    type = string 
    default ="app-gw"
    }


variable "app_gateway_fullname" { default ="" }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "firewall_policy_id" { default = null }
variable "tags" { default ={} }

variable "subnet_id" { type = string }
variable "backend_targets" {}
#variable "routing_rules" {}
variable "key_vault_name" {}
variable "certificates_custom" { default = {} }
variable "initialize_certificates" { default = true }

# variable "request_timeout" { default = 30 }
# variable "probe_interval" { default = 30 }
# variable "probe_timeout" { default = 30 }
# variable "unhealthy_threshold" { default = 5 }
variable "letsencrypt_backend_target" { default = null }
variable "enable_http2" { default = true }
variable "gateway_ip_name" { default = "appgw-ip-config" }
variable "frontend_ip_name" { default = "appgw-public-frontend-ip" }


variable "autoscale_configuration" { default = false }
variable "autoscale_min_capacity" { default = null }
variable "autoscale_max_capacity" { default = null }

variable "listeners" {}
variable "redirections" { default = {} }

variable "default_backend_settings" {
    default = {
        port = 443
        protocol = "Https"
        cookie_based_affinity = "Enabled"
        request_timeout = 30
        # pick_host_name_from_backend_http_settings = true
        # pick_host_name_from_backend_address = true
        probe_interval = 30
        probe_timeout = 10
        probe_unhealthy_threshold = 5
        probe_path = "/"
        status_code = ["200-499"]
    }
}

variable "app_gw_custom_mi" { default = "" }
variable "public_ip_name" { default = "" }

variable "sku_capacity" { 
    type = number
    default = 1 
    }

variable "sku_name" { 
    type = string 
    default ="Standard_v2"
    }

variable "zones" { 
    type = list 
    default = ["1", "2", "3"]
    }

variable "pip_zones" { 
    type = list 
    default = ["1", "2", "3"]
    }

variable "ssl_profiles" {
    default = {
        "default" = {
            "policy_name" = "AppGwSslPolicy20220101"
        }
    }
}

variable "security_headers" {
  type = map(map(string))
  default = {
    "default" = {
        "Strict-Transport-Security" = "max-age=2592000; preload"
        "X-Frame-Options"           = "SAMEORIGIN"
        "X-Content-Type-Options"    = "nosniff"
        "Referrer-Policy"           = "same-origin"
        "Permissions-Policy"        = "geolocation=(), microphone=()"
        #"Content-Security-Policy"   = "default-src 'self'"        
    }
  }
}

variable "security_headers_enabled" { default = false }

variable "global_ssl_policy" { default = null }
variable "pip_extra_tags" { default = {} }

variable "waf_configuration" { default = {} }


variable "default_waf_configuration" { 
    default = {
        enabled                  = false
        file_upload_limit_mb     = 100
        firewall_mode            = "Detection"
        max_request_body_size_kb = 128
        request_body_check       = true
        rule_set_type            = "OWASP"
        rule_set_version         = "3.2"
    } 

}

variable "frontend_port_names_overrides" { default = {} }

## Alerts
variable "enable_alerts" { default = false }
variable "backend_alerts_enable_default" { default = false }
variable "alerts_email" { default = null }


## Logging
variable "enable_logging" { default = true }

variable "enable_appgw_access_logs" { default = true }
variable "enable_appgw_performance_logs" { default = true }
variable "enable_appgw_firewall_logs" { default = true }

variable "logs_sa_name" { default = null }
variable "logs_sa_account_tier" { default = "Standard" }
variable "logs_sa_replication_type" { default = "LRS" }


variable "alert_tags" { default = {} }
variable "sa_tags" { default = {} }
