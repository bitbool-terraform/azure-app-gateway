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
  threshold        = local.alerts.threshold
}

  action {
    action_group_id = var.app_gw.alerts_action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "appgw_backend_service_unhealthy" {
  count = local.alerts.enable == true ? 1 : 0
  
  name                = format("%s-backend-svc-unhealthy",local.app_gateway_name)
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
  threshold        = local.alerts.threshold

  dimension {
    name     = "BackendSettingsPool"
    operator = "Include"
    values   = ["*"]
  }
}

  action {
    action_group_id = var.app_gw.alerts_action_group_id
  }
}