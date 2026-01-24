resource "azurerm_storage_account" "appgw_logs" {
  count = var.enable_logging == true ? 1 : 0

  name                     = format("%slogs", replace(local.app_gateway_name, "-", ""))
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.sa_account_tier
  account_replication_type = var.sa_replication_type
}

resource "azurerm_monitor_diagnostic_setting" "appgw_diag" {
  count = var.enable_logging == true ? 1 : 0

  name               = format("%s-diag-logs", replace(local.app_gateway_name, "-", ""))

  target_resource_id = azurerm_application_gateway.gateway.id
  storage_account_id = azurerm_storage_account.appgw_logs[0].id

  dynamic "enabled_log" {
    for_each = var.enable_appgw_access_logs ? [1] : []
    content {
      category = "ApplicationGatewayAccessLog"
    }
  }

  dynamic "enabled_log" {
    for_each = var.enable_appgw_performance_logs ? [1] : []
    content {
      category = "ApplicationGatewayPerformanceLog"
    }
  }

  dynamic "enabled_log" {
    for_each = var.enable_appgw_firewall_logs ? [1] : []
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
