variable "app_gw" {}

variable "default_name" { default ="app-gw" }

variable "default_sku_capacity" { default = 1 }
variable "default_sku_name" { default ="Standard_v2" }
variable "default_frontend_ip_name" { default = "appgw-public-frontend-ip" }
variable "default_gateway_ip_name" { default = "appgw-ip-config" }
variable "default_autoscale_configuration" { default = false }

variable "default_ssl_profiles" {
    default = {
        "default" = {
            "policy_name" = "AppGwSslPolicy20220101"
        }
    }
}

variable "default_zones" { 
    type = list 
    default = ["1", "2", "3"]
    }

variable "default_pip_zones" { 
    type = list 
    default = ["1", "2", "3"]
    }

variable "default_security_headers_enabled" { default = false }

variable "default_security_headers" {
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

variable "default_alerts" { 
    default = {
        enable = false
        email = "alerts@bitbool.net"
        severity = 1
        frequency = "PT1M"
        window_size = "PT5M"
    }
}

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

variable "default_logging" { 
    default = {
        enable = true
        enable_appgw_access_logs = true
        enable_appgw_performance_logs = true
        enable_appgw_firewall_logs = true
        sa_name = null
        sa_account_tier = "Standard"
        sa_replication_type = "LRS"
    }
}

variable "default_enable_http2" { default = true }




# variable "listeners" {}
# variable "redirections" { default = {} }
# variable "backend_targets" {}




variable "certificates_custom" { default = {} }

