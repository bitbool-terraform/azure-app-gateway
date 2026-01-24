resource "azurerm_monitor_action_group" "appgw_alerts" {
  count = var.enable_alerts == true ? 1 : 0
  name                = format("%s-backend-alerts",local.app_gateway_name)
  resource_group_name = var.resource_group_name
  short_name          = "appgw-alert"

  email_receiver {
    name          = "bitbool-alert-email"
    email_address = var.alerts_email
  }
}


resource "azurerm_monitor_metric_alert" "appgw_backend_unhealthy" {
  for_each = local.alertable_backend_http_settings
  
  name                = format("%s-backend-unhealthy-%s",local.app_gateway_name,each.key)
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.gateway.id]
  description         = format("%s backend health check for %s",local.app_gateway_name,each.key)
  severity            = lookup(each.value,"alert_severity",1)
  enabled             = true
  frequency           = lookup(each.value,"alert_frequency","PT1M")
  window_size         = lookup(each.value,"alert_window_size","PT5M")

criteria {
  metric_namespace = "Microsoft.Network/applicationGateways"
  metric_name      = "UnhealthyHostCount"
  aggregation      = "Average"
  operator         = "GreaterThan"
  threshold        = 0

  dimension {
    name     = "BackendSettingsPool"
    operator = "Include"
    values   = [each.key]
  }
}

  action {
    action_group_id = azurerm_monitor_action_group.appgw_alerts[0].id
  }
}
