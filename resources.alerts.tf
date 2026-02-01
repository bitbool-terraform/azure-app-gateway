resource "azurerm_monitor_action_group" "appgw_alerts" {
  count = var.enable_alerts == true ? 1 : 0
  name                = format("%s-backend-alerts",local.app_gateway_name)
  resource_group_name = var.resource_group_name
  short_name          = "appgw-alert"
  tags                = var.alert_tags
  
  email_receiver {
    name          = "bitbool-alert-email"
    email_address = var.alerts_email
  }
}


resource "azurerm_monitor_metric_alert" "appgw_backend_unhealthy" {
  count = var.enable_alerts == true ? 1 : 0
  
  name                = format("%s-backend-unhealthy",local.app_gateway_name)
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.gateway.id]
  description         = format("%s backend health check",local.app_gateway_name)
  severity            = var.alert_severity
  enabled             = true
  frequency           = var.alert_frequency
  window_size         = var.alert_window_size
  tags                = var.alert_tags

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