resource "elasticstack_kibana_alerting_rule" "kibana_alerts" {
  for_each = { for idx, alert in var.alerts : alert.name => alert }

  name        = each.value.name
  consumer    = "alerts"
  notify_when = each.value.notify_when
  rule_type_id = each.value.rule_type_id
  interval    = each.value.interval
  enabled     = each.value.enabled
  
  params = jsonencode(each.value.params)
}

# Example usage in tfvars:
# alerts = [
#   {
#     name = "LatencyDetected"
#     rule_type_id = "apm.transaction_duration"
#     interval = "1m"
#     enabled = true
#     notify_when = "onActionGroupChange"
#     params = {
#       threshold = 1500
#       windowSize = 1
#       windowUnit = "m"
#       environment = "ENVIRONMENT_ALL"
#       serviceName = ""
#       transactionType = "ENVIRONMENT_ALL"
#     }
#   },
#   {
#     name = "ErrorExceeded"
#     rule_type_id = "apm.error_rate"
#     interval = "1m"
#     enabled = true
#     notify_when = "onActionGroupChange"
#     params = {
#       threshold = 5
#       windowSize = 1
#       windowUnit = "m"
#       environment = "ENVIRONMENT_ALL"
#       serviceName = ""
#     }
#   },
#   {
#     name = "TestIndexAlert"
#     rule_type_id = ".index-threshold"
#     interval = "1m"
#     enabled = true
#     notify_when = "onActiveAlert"
#     params = {
#       aggType = "avg"
#       groupBy = "top"
#       termSize = 10
#       timeWindowSize = 10
#       timeWindowUnit = "s"
#       threshold = [10]
#       thresholdComparator = ">"
#       index = ["test-index"]
#       timeField = "@timestamp"
#       aggField = "version"
#       termField = "name"
#     }
#   }
# ]