resource "azurerm_storage_account" "appgw_logs" {
  count = local.logging.enable == true ? 1 : 0

  name                     = local.logging.sa_name == null ? format("%slogs", lower(replace(local.app_gateway_name, "-", ""))) : local.logging.sa_name
  resource_group_name      = var.app_gw.resource_group
  location                 = var.app_gw.location
  account_tier             = local.logging.sa_account_tier
  account_replication_type = local.logging.sa_replication_type
  tags                     = local.sa_tags

}

resource "azurerm_monitor_diagnostic_setting" "appgw_diag" {
  count = local.logging.enable == true ? 1 : 0

  name               = format("%s-diag-logs", replace(local.app_gateway_name, "-", ""))

  target_resource_id = azurerm_application_gateway.gateway.id
  storage_account_id = azurerm_storage_account.appgw_logs[0].id

  dynamic "enabled_log" {
    for_each = local.logging.enable_appgw_access_logs ? [1] : []
    content {
      category = "ApplicationGatewayAccessLog"
    }
  }

  dynamic "enabled_log" {
    for_each = local.logging.enable_appgw_performance_logs ? [1] : []
    content {
      category = "ApplicationGatewayPerformanceLog"
    }
  }

  dynamic "enabled_log" {
    for_each = local.logging.enable_appgw_firewall_logs ? [1] : []
    content {
      category = "ApplicationGatewayFirewallLog"
    }
  }

  # lifecycle { # Azure maybe create pseudo-diffs
  #   ignore_changes = [
  #     enabled_log
  #   ]
  # }
}
