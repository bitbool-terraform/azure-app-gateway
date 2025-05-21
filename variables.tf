variable "project" { type = string }
variable "systemenv" { type = string }
variable "name" { 
    type = string 
    default ="app-gw"
    }


variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "subnet_id" { type = string }
variable "backend_targets" {}
variable "routing_rules" {}
variable "key_vault_name" {}
variable "certificates_custom" { default = {} }
variable "initialize_certificates" { default = true }

variable "cookie_based_affinity" { default = "Disabled" }
variable "request_timeout" { default = 30 }

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