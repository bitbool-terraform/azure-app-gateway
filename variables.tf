variable "project" { type = string }
variable "systemenv" { type = string }
variable "name" { 
    type = string 
    default ="app-gw"
    }


variable "app_gateway_fullname" { default ="" }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "firewall_policy_id" { default =null }
variable "tags" { default =null }

variable "subnet_id" { type = string }
variable "backend_targets" {}
variable "routing_rules" {}
variable "key_vault_name" {}
variable "certificates_custom" { default = {} }
variable "initialize_certificates" { default = true }

variable "cookie_based_affinity" { default = "Disabled" }
variable "request_timeout" { default = 30 }
variable "probe_interval" { default = 30 }
variable "probe_timeout" { default = 30 }
variable "unhealthy_threshold" { default = 20 }

variable "app_gw_custom_mi" { default = "" }

variable "capacity" { 
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