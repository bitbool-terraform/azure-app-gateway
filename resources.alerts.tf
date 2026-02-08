resource "azurerm_monitor_action_group" "appgw_alerts" {
  count = local.alerts.enable == true ? 1 : 0
  name                = format("%s-backend-alerts",local.app_gateway_name)
  resource_group_name = var.app_gw.resource_group
  short_name          = "appgw-alert"
  tags                = local.alerts_tags
  
  email_receiver {
    name          = "bitbool-alert-email"
    email_address = local.alerts.email
  }
}

resource "azurerm_monitor_metric_alert" "appgw_backend_unhealthy" {
  count = local.alerts.enable == true ? 1 : 0
  
  name                = format("%s-backend-unhealthy",local.app_gateway_name)
  resource_group_name = var.app_gw.resource_group
  scopes              = [azurerm_application_gateway.gateway.id]
  description         = format("%s backend health check",local.app_gateway_name)
  severity            = local.alerts.severity
  enabled             = true
  frequency           = local.alerts.frequency
  window_size         = local.alerts.window_size
  tags                = local.alerts_tags

criteria {
  metric_namespace = "Microsoft.Network/applicationGateways"
  metric_name      = "UnhealthyHostCount"
  aggregation      = "Average"
  operator         = "GreaterThan"
  threshold        = 0
}

  action {
    action_group_id = azurerm_monitor_action_group.appgw_alerts[0].id
  }
}