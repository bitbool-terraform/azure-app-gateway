output "backend_address_pools" {
  value = local.backend_address_pools
}

# output "rules_grouped_by_hostname" {
#   value = local.rules_grouped_by_hostname
# }

output "http_listeners" {
  value = local.http_listeners
}

output "ssl_certificates" {
  value = local.ssl_certificates
}

output "backend_http_settings" {
  value = local.backend_http_settings
}
output "url_path_maps" {
  value = local.url_path_maps
}
# output "url_path_maps_http" {
#   value = local.url_path_maps_http
# }
# output "url_path_maps_ssl" {
#   value = local.url_path_maps_ssl
# }
# output "redirections" {
#   value = local.redirections
# }

