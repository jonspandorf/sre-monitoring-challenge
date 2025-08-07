alerts = [
  {
    name = "LatencyDetected"
    rule_type_id = "apm.transaction_duration"
    interval = "1m"
    enabled = true
    notify_when = "onActionGroupChange"
    tags = ["environment:all", "service:apm"]
    params = {
      threshold = [1500]

      timeWindowSize = 1
      timeWindowUnit = "m"
      index - ["apm-latency"]
      aggField = "duration"
      transactionType = "ENVIRONMENT_ALL"
    }
  },
  {
    name = "ErrorExceeded"
    rule_type_id = "apm.error_rate"
    interval = "1m"
    enabled = true
    notify_when = "onActionGroupChange"
    tags = ["environment:all", "service:apm"]
    params = {
      threshold = 5
      windowSize = 1
      windowUnit = "m"
      environment = "ENVIRONMENT_ALL"
      serviceName = ""
    }
  },
  {
    name = "TestIndexAlert"
    rule_type_id = ".index-threshold"
    interval = "1m"
    enabled = true
    notify_when = "onActiveAlert"
    tags = ["environment:test", "index:test-index"]
    params = {
      aggType = "avg"
      groupBy = "top"
      termSize = 10
      timeWindowSize = 10
      timeWindowUnit = "s"
      threshold = [10]
      thresholdComparator = ">"
      index = ["test-index"]
      timeField = "@timestamp"
      aggField = "version"
      termField = "name"
    }
  }
] 